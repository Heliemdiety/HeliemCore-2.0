import rv32_pkg::*;

module riscv_core_top (
    input  logic clk,
    input  logic rst_n,
    input  word_t synth_inst,  // <-- The "Unknown Void" instruction ,, vivado only executes the implentation for the logic that is inside the ROM... so we give here a dummy wire as input.. now it does not know which instruction to execute , so it has to execute the implementation for all the logic.. hence we will get the correct number of LUTs and FFs..
    output logic [31:0] dummy_out     // dummy output for implementation 
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
    word_t   if_id_pc_plus_4; 

    id_ex_t  id_ex_reg;
    word_t   id_ex_pc_plus_4;

    ex_mem_t ex_mem_reg;
    word_t   ex_mem_pc_plus_4;

    mem_wb_t mem_wb_reg;

    // -------------------------------------------------------------------------
    // UVM / RVFI PIPELINE TRACKERS (IGNORED DURING SYNTHESIS!)
    // These flip-flops carry the PC and Instruction to the WB stage for UVM.
    //Because we used `ifndef SYNTHESIS, Vivado will completely ignore all that extra UVM tracking logic we just added, giving you the pure, highly-optimized area of CPU.
    // -------------------------------------------------------------------------
`ifndef SYNTHESIS
    word_t id_ex_rvfi_pc, id_ex_rvfi_inst;
    word_t ex_mem_rvfi_pc, ex_mem_rvfi_inst;
    word_t mem_wb_rvfi_pc, mem_wb_rvfi_inst;
`endif

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_reg        <= '0;
            if_id_pc_plus_4  <= '0;
            id_ex_reg        <= '0;
            id_ex_pc_plus_4  <= '0;
            ex_mem_reg       <= '0;
            ex_mem_pc_plus_4 <= '0;
            mem_wb_reg       <= '0;

`ifndef SYNTHESIS
            id_ex_rvfi_pc <= '0; id_ex_rvfi_inst <= '0;
            ex_mem_rvfi_pc <= '0; ex_mem_rvfi_inst <= '0;
            mem_wb_rvfi_pc <= '0; mem_wb_rvfi_inst <= '0;
`endif

        end else begin
            
            // --- IF/ID Register ---
            if (flush_if_id) begin
                if_id_reg      <= '0;
                if_id_reg.inst <= 32'h00000033; // NOP
            end else if (!stall_id) begin
                if_id_reg.pc   <= if_pc;
                if_id_reg.inst <= if_inst;
                if_id_pc_plus_4 <= if_pc_plus_4;
            end

            // --- ID/EX Register ---
            if (flush_id_ex) begin
                id_ex_reg       <= '0; 
                id_ex_pc_plus_4 <= '0;
`ifndef SYNTHESIS
                id_ex_rvfi_pc   <= '0;
                id_ex_rvfi_inst <= 32'h00000033; // Track flushed instruction as NOP
`endif
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
`ifndef SYNTHESIS
                // Carry the exact PC and Instruction from the previous stage
                id_ex_rvfi_pc   <= if_id_reg.pc;
                id_ex_rvfi_inst <= if_id_reg.inst;
`endif
            end

            // --- EX/MEM Register ---
            ex_mem_reg       <= ex_mem_data_next;
            ex_mem_pc_plus_4 <= id_ex_pc_plus_4;
`ifndef SYNTHESIS
            ex_mem_rvfi_pc   <= id_ex_rvfi_pc;
            ex_mem_rvfi_inst <= id_ex_rvfi_inst;
`endif

            // --- MEM/WB Register ---
            mem_wb_reg       <= mem_wb_data_next;
`ifndef SYNTHESIS
            mem_wb_rvfi_pc   <= ex_mem_rvfi_pc;
            mem_wb_rvfi_inst <= ex_mem_rvfi_inst;
`endif
        end
    end

    // =========================================================================
    // 3. MODULE INSTANTIATIONS
    // =========================================================================

    rv32_fetch fetch_inst (
        .clk(clk), .rst_n(rst_n),
        .stall_if(stall_if), .ex_branch_taken(ex_branch_taken),
        .ex_jump_taken(ex_jump_taken), .ex_target_addr(ex_target_addr),
        .pc(if_pc), .pc_plus_4(if_pc_plus_4)
    );

    // rv32_imem imem_inst (
    //     .addr(if_pc), .inst(if_inst)
    // );


    // --- INSTRUCTION MEMORY (Blindfolding Vivado during Synthesis) ---When you click Run Simulation, it runs your A* UVM testbench perfectly because it uses the real imem.
// But when you click Run Implementation, Vivado deletes the ROM, looks at synth_inst (which is an unknown input from the outside world), and is MATHEMATICALLY FORCED to synthesize your entire ALU, all 32 registers, your entire Instruction Decoder, and every single Forwarding multiplexer.
`ifndef SYNTHESIS
    // During Simulation, use your real ROM with your Dijkstra/A* firmware         
    rv32_imem imem_inst (
        .addr(if_pc), .inst(if_inst)
    );
`else
    // During Synthesis, Vivado is forced to accept completely random 
    // instructions from the outside world pin!
    assign if_inst = synth_inst;
`endif

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

    rv32_execute ex_inst (
        .id_ex_reg(id_ex_reg),
        .forward_a(forward_a), .forward_b(forward_b),
        .forward_ex_data(ex_mem_reg.alu_result), 
        .forward_mem_data(rf_wdata),             
        .ex_branch_taken(ex_branch_taken), .ex_jump_taken(ex_jump_taken),
        .ex_target_addr(ex_target_addr), .ex_mem_data(ex_mem_data_next)
    );

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

    rv32_writeback wb_inst (
        .mem_wb_reg(mem_wb_reg),
        .rf_we(rf_we), .rf_waddr(rf_waddr), .rf_wdata(rf_wdata)
    );

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

    // Force Vivado to keep the CPU alive by routing the final math to an output pin! DUMMY OUTPUT
    assign dummy_out = rf_wdata;

endmodule






// This is a UVM Architecture Bug, and it is called "Pipeline Skew" (or the "Frankenstein Transaction").
// The industry standard solution is called RVFI (RISC-V Formal Interface). 
// The designers are forced to add extra flip-flops to the pipeline whose only job is to carry the PC and Instruction through the Decode, 
// Execute, and Memory stages, all the way to Writeback, specifically so the UVM Monitor can read them at the exact same time as rf_wdata.