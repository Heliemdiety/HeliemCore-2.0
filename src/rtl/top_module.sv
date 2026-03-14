import rv32_pkg::*;

module riscv_core_top (
    input  logic clk,
    input  logic rst_n
);

    // =========================================================================
    // 1. INTERCONNECT WIRES & COMBINATIONAL SIGNALS
    // =========================================================================

    // IF Stage
    word_t if_pc, if_pc_plus_4, if_inst;
    
    // ID Stage
    control_t  id_ctrl;
    word_t     id_imm;
    word_t     id_rs1_data, id_rs2_data;
    reg_addr_t id_rs1, id_rs2, id_rd;
    logic [2:0] id_funct3;
    
    // EX Stage
    logic       ex_branch_taken, ex_jump_taken;
    word_t      ex_target_addr;
    ex_mem_t    ex_mem_data_next; // Combinational output of EX stage
    
    // MEM Stage
    word_t      dmem_addr, dmem_wdata, dmem_rdata;
    logic       dmem_wen, dmem_ren;
    logic [3:0] dmem_strb;
    mem_wb_t    mem_wb_data_next; // Combinational output of MEM stage
    
    // WB Stage & Register File
    logic       rf_we;
    reg_addr_t  rf_waddr;
    word_t      rf_wdata;
    
    // Hazard & Forwarding
    logic       stall_if, stall_id, flush_if_id, flush_id_ex;
    logic [1:0] forward_a, forward_b;

    // =========================================================================
    // 2. PIPELINE REGISTERS (The Flip-Flops)
    // =========================================================================

    if_id_t  if_id_reg;
    word_t   if_id_pc_plus_4; // Piped alongside the struct for JAL/JALR

    id_ex_t  id_ex_reg;
    word_t   id_ex_pc_plus_4;

    ex_mem_t ex_mem_reg;
    word_t   ex_mem_pc_plus_4;

    mem_wb_t mem_wb_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all pipeline registers to 0
            if_id_reg        <= '0;
            if_id_pc_plus_4  <= '0;
            id_ex_reg        <= '0;
            id_ex_pc_plus_4  <= '0;
            ex_mem_reg       <= '0;
            ex_mem_pc_plus_4 <= '0;
            mem_wb_reg       <= '0;
        end else begin
            
            // --- IF/ID Register ---
            if (flush_if_id) begin
                if_id_reg      <= '0;
                if_id_reg.inst <= 32'h00000033; // Inject NOP (ADD x0, x0, x0)
            end else if (!stall_id) begin
                if_id_reg.pc   <= if_pc;
                if_id_reg.inst <= if_inst;
                if_id_pc_plus_4 <= if_pc_plus_4;
            end

            // --- ID/EX Register ---
            if (flush_id_ex) begin
                id_ex_reg       <= '0; // Control signals go 0 (Safe NOP state)
                id_ex_pc_plus_4 <= '0;
            end else begin
                id_ex_reg.pc       <= if_id_reg.pc;
                id_ex_reg.imm      <= id_imm;
                id_ex_reg.rs1_data <= id_rs1_data;
                id_ex_reg.rs2_data <= id_rs2_data;
                id_ex_reg.rs1      <= id_rs1;
                id_ex_reg.rs2      <= id_rs2;
                id_ex_reg.rd       <= id_rd;
                id_ex_reg.funct3   <= id_funct3;
                id_ex_reg.ctrl     <= id_ctrl;
                id_ex_pc_plus_4    <= if_id_pc_plus_4;
            end

            // --- EX/MEM Register ---
            ex_mem_reg       <= ex_mem_data_next;
            ex_mem_pc_plus_4 <= id_ex_pc_plus_4;

            // --- MEM/WB Register ---
            mem_wb_reg       <= mem_wb_data_next;
        end
    end

    // =========================================================================
    // 3. MODULE INSTANTIATIONS
    // =========================================================================

    // --- INSTRUCTION FETCH (IF) ---
    rv32_fetch fetch_inst (
        .clk(clk), .rst_n(rst_n),
        .stall_if(stall_if), .ex_branch_taken(ex_branch_taken),
        .ex_jump_taken(ex_jump_taken), .ex_target_addr(ex_target_addr),
        .pc(if_pc), .pc_plus_4(if_pc_plus_4)
    );

    rv32_imem imem_inst (
        .addr(if_pc), .inst(if_inst)
    );

    // --- INSTRUCTION DECODE (ID) ---
    // Extract fields from the fetched instruction
    assign id_rs1    = if_id_reg.inst[19:15];
    assign id_rs2    = if_id_reg.inst[24:20];
    assign id_rd     = if_id_reg.inst[11:7];
    assign id_funct3 = if_id_reg.inst[14:12];

    instruction_decoder decode_inst (
        .inst(if_id_reg.inst), .ctrl(id_ctrl)
    );

    rv32_immgen immgen_inst (
        .inst(if_id_reg.inst), .imm(id_imm)
    );

    rv32_regfile rf_inst (
        .clk(clk), .rst_n(rst_n),
        .rs1_addr(id_rs1), .rs2_addr(id_rs2),
        .rs1_data(id_rs1_data), .rs2_data(id_rs2_data),
        .write_en(rf_we), .write_addr(rf_waddr), .write_data(rf_wdata)
    );

    // --- EXECUTE (EX) ---
    rv32_execute ex_inst (
        .id_ex_reg(id_ex_reg),
        .forward_a(forward_a), .forward_b(forward_b),
        .forward_ex_data(ex_mem_reg.alu_result), // Data bypassing from EX/MEM
        .forward_mem_data(rf_wdata),             // Data bypassing from MEM/WB
        .ex_branch_taken(ex_branch_taken), .ex_jump_taken(ex_jump_taken),
        .ex_target_addr(ex_target_addr), .ex_mem_data(ex_mem_data_next)
    );

    // --- MEMORY (MEM) ---
    rv32_memory mem_inst (
        .ex_mem_reg(ex_mem_reg), .ex_mem_pc_plus_4(ex_mem_pc_plus_4),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_wen(dmem_wen),
        .dmem_ren(dmem_ren), .dmem_strb(dmem_strb), .dmem_rdata(dmem_rdata),
        .mem_wb_data(mem_wb_data_next)
    );

    rv32_dmem dmem_inst (
        .clk(clk), .addr(dmem_addr), .wdata(dmem_wdata),
        .wen(dmem_wen), .ren(dmem_ren), .strb(dmem_strb), .rdata(dmem_rdata)
    );

    // --- WRITEBACK (WB) ---
    rv32_writeback wb_inst (
        .mem_wb_reg(mem_wb_reg),
        .rf_we(rf_we), .rf_waddr(rf_waddr), .rf_wdata(rf_wdata)
    );

    // --- CONTROL: HAZARD & FORWARDING ---
    rv32_hazard hazard_inst (
        .id_rs1(id_rs1), .id_rs2(id_rs2), .id_ex_reg(id_ex_reg),
        .ex_branch_taken(ex_branch_taken), .ex_jump_taken(ex_jump_taken),
        .stall_if(stall_if), .stall_id(stall_id),
        .flush_if_id(flush_if_id), .flush_id_ex(flush_id_ex)
    );

    rv32_forward forward_inst (
        .ex_rs1(id_ex_reg.rs1), .ex_rs2(id_ex_reg.rs2),
        .ex_mem_reg(ex_mem_reg), .mem_wb_reg(mem_wb_reg),
        .forward_a(forward_a), .forward_b(forward_b)
    );

endmodule