import rv32_pkg::*;

module riscv_core_top (
    input  logic clk,
    input  logic rst_n,

    // =========================================================================
    // AXI4 MASTER 0: INSTRUCTION CACHE BUS
    // =========================================================================
    output logic [31:0] m_axi_if_araddr,
    output logic [7:0]  m_axi_if_arlen,
    output logic [2:0]  m_axi_if_arsize,
    output logic [1:0]  m_axi_if_arburst,
    output logic        m_axi_if_arvalid,
    input  logic        m_axi_if_arready,
    input  logic [31:0] m_axi_if_rdata,
    input  logic [1:0]  m_axi_if_rresp,
    input  logic        m_axi_if_rlast,
    input  logic        m_axi_if_rvalid,
    output logic        m_axi_if_rready,

    // =========================================================================
    // AXI4 MASTER 1: DATA CACHE BUS
    // =========================================================================
    output logic [31:0] m_axi_mem_awaddr,
    output logic [7:0]  m_axi_mem_awlen,
    output logic [2:0]  m_axi_mem_awsize,
    output logic [1:0]  m_axi_mem_awburst,
    output logic        m_axi_mem_awvalid,
    input  logic        m_axi_mem_awready,
    output logic [31:0] m_axi_mem_wdata,
    output logic [3:0]  m_axi_mem_wstrb,
    output logic        m_axi_mem_wlast,
    output logic        m_axi_mem_wvalid,
    input  logic        m_axi_mem_wready,
    input  logic [1:0]  m_axi_mem_bresp,
    input  logic        m_axi_mem_bvalid,
    output logic        m_axi_mem_bready,
    output logic [31:0] m_axi_mem_araddr,
    output logic [7:0]  m_axi_mem_arlen,
    output logic [2:0]  m_axi_mem_arsize,
    output logic [1:0]  m_axi_mem_arburst,
    output logic        m_axi_mem_arvalid,
    input  logic        m_axi_mem_arready,
    input  logic [31:0] m_axi_mem_rdata,
    input  logic [1:0]  m_axi_mem_rresp,
    input  logic        m_axi_mem_rlast,
    input  logic        m_axi_mem_rvalid,
    output logic        m_axi_mem_rready
);

    // =========================================================================
    // 1. INTERCONNECT WIRES & COMBINATIONAL SIGNALS
    // =========================================================================
    word_t if_pc, if_pc_plus_4, if_inst;
    control_t  id_ctrl;
    word_t     id_imm, id_rs1_data, id_rs2_data;
    reg_addr_t id_rs1, id_rs2, id_rd;
    logic [2:0] id_funct3;
    logic       ex_branch_taken, ex_jump_taken;
    word_t      ex_target_addr;
    ex_mem_t    ex_mem_data_next;
    mem_wb_t    mem_wb_data_next;
    logic       rf_we;
    reg_addr_t  rf_waddr;
    word_t      rf_wdata;
    logic       stall_if, stall_id, flush_if_id, flush_id_ex;
    logic       global_stall, if_bus_stall, mem_bus_stall;
    logic [1:0] forward_a, forward_b;

    // BIU Wires
    logic [31:0] cpu_req_addr, cpu_instr_out;
    logic        cpu_req_valid, cpu_req_ready, cpu_instr_valid;
    logic [31:0] cpu_load_addr, cpu_load_data, cpu_store_addr, cpu_store_data;
    logic [3:0]  cpu_store_strb;
    logic        cpu_load_valid, cpu_load_ready, cpu_load_valid_out;
    logic        cpu_store_valid, cpu_store_ready, cpu_trap_exception;

    // =========================================================================
    // 2. PIPELINE REGISTERS (The Flip-Flops)
    // =========================================================================
    if_id_t  if_id_reg;   word_t if_id_pc_plus_4; 
    id_ex_t  id_ex_reg;   word_t id_ex_pc_plus_4;
    ex_mem_t ex_mem_reg;  word_t ex_mem_pc_plus_4;
    mem_wb_t mem_wb_reg;

`ifndef SYNTHESIS
    word_t id_ex_rvfi_pc, id_ex_rvfi_inst;
    word_t ex_mem_rvfi_pc, ex_mem_rvfi_inst;
    word_t mem_wb_rvfi_pc, mem_wb_rvfi_inst;
`endif

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_reg <= '0; if_id_pc_plus_4 <= '0;
            id_ex_reg <= '0; id_ex_pc_plus_4 <= '0;
            ex_mem_reg<= '0; ex_mem_pc_plus_4<= '0;
            mem_wb_reg<= '0;
`ifndef SYNTHESIS
            id_ex_rvfi_pc <= '0; id_ex_rvfi_inst <= '0;
            ex_mem_rvfi_pc <= '0; ex_mem_rvfi_inst <= '0;
            mem_wb_rvfi_pc <= '0; mem_wb_rvfi_inst <= '0;
`endif
        end else if (!global_stall) begin 
            // THE GLOBAL STALL: Completely freezes the pipeline during AXI wait states!
            
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
                id_ex_rvfi_inst <= 32'h00000033;
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
    // 3. BUS INTERFACE UNITS (BIU)
    // =========================================================================
    axi4_ifetch_biu ifetch_biu_inst (
        .clk(clk), .rst_n(rst_n),
        .cpu_req_addr(cpu_req_addr), .cpu_req_valid(cpu_req_valid), .cpu_req_ready(cpu_req_ready),
        .cpu_instr_out(cpu_instr_out), .cpu_instr_valid(cpu_instr_valid),
        .m_axi_araddr(m_axi_if_araddr), .m_axi_arlen(m_axi_if_arlen), .m_axi_arsize(m_axi_if_arsize),
        .m_axi_arburst(m_axi_if_arburst), .m_axi_arvalid(m_axi_if_arvalid), .m_axi_arready(m_axi_if_arready),
        .m_axi_rdata(m_axi_if_rdata), .m_axi_rresp(m_axi_if_rresp), .m_axi_rlast(m_axi_if_rlast),
        .m_axi_rvalid(m_axi_if_rvalid), .m_axi_rready(m_axi_if_rready)
    );

    axi4_dmem_biu dmem_biu_inst (
        .clk(clk), .rst_n(rst_n),
        .cpu_load_addr(cpu_load_addr), .cpu_load_valid(cpu_load_valid), .cpu_load_ready(cpu_load_ready),
        .cpu_load_data(cpu_load_data), .cpu_load_valid_out(cpu_load_valid_out),
        .cpu_store_addr(cpu_store_addr), .cpu_store_data(cpu_store_data), .cpu_store_strb(cpu_store_strb),
        .cpu_store_valid(cpu_store_valid), .cpu_store_ready(cpu_store_ready), .cpu_trap_exception(cpu_trap_exception),
        .m_axi_awaddr(m_axi_mem_awaddr), .m_axi_awlen(m_axi_mem_awlen), .m_axi_awsize(m_axi_mem_awsize),
        .m_axi_awburst(m_axi_mem_awburst), .m_axi_awvalid(m_axi_mem_awvalid), .m_axi_awready(m_axi_mem_awready),
        .m_axi_wdata(m_axi_mem_wdata), .m_axi_wstrb(m_axi_mem_wstrb), .m_axi_wlast(m_axi_mem_wlast),
        .m_axi_wvalid(m_axi_mem_wvalid), .m_axi_wready(m_axi_mem_wready),
        .m_axi_bresp(m_axi_mem_bresp), .m_axi_bvalid(m_axi_mem_bvalid), .m_axi_bready(m_axi_mem_bready),
        .m_axi_araddr(m_axi_mem_araddr), .m_axi_arlen(m_axi_mem_arlen), .m_axi_arsize(m_axi_mem_arsize),
        .m_axi_arburst(m_axi_mem_arburst), .m_axi_arvalid(m_axi_mem_arvalid), .m_axi_arready(m_axi_mem_arready),
        .m_axi_rdata(m_axi_mem_rdata), .m_axi_rresp(m_axi_mem_rresp), .m_axi_rlast(m_axi_mem_rlast),
        .m_axi_rvalid(m_axi_mem_rvalid), .m_axi_rready(m_axi_mem_rready)
    );

    // =========================================================================
    // 4. MODULE INSTANTIATIONS
    // =========================================================================
    rv32_fetch fetch_inst (
        .clk(clk), .rst_n(rst_n), .global_stall(global_stall), .stall_if(stall_if),
        .ex_branch_taken(ex_branch_taken), .ex_jump_taken(ex_jump_taken), .ex_target_addr(ex_target_addr),
        .pc(if_pc), .pc_plus_4(if_pc_plus_4), .fetched_inst(if_inst),
        .cpu_req_addr(cpu_req_addr), .cpu_req_valid(cpu_req_valid), .cpu_req_ready(cpu_req_ready),
        .cpu_instr_out(cpu_instr_out), .cpu_instr_valid(cpu_instr_valid), .if_bus_stall(if_bus_stall)
    );

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
        .clk(clk), .rst_n(rst_n), .global_stall(global_stall),
        .ex_mem_reg(ex_mem_reg), .ex_mem_pc_plus_4(ex_mem_pc_plus_4),
        .cpu_load_addr(cpu_load_addr), .cpu_load_valid(cpu_load_valid), .cpu_load_ready(cpu_load_ready),
        .cpu_load_data(cpu_load_data), .cpu_load_valid_out(cpu_load_valid_out),
        .cpu_store_addr(cpu_store_addr), .cpu_store_data(cpu_store_data), .cpu_store_strb(cpu_store_strb),
        .cpu_store_valid(cpu_store_valid), .cpu_store_ready(cpu_store_ready), .cpu_trap_exception(cpu_trap_exception),
        .mem_bus_stall(mem_bus_stall), .mem_wb_data(mem_wb_data_next)
    );

    rv32_writeback wb_inst (
        .mem_wb_reg(mem_wb_reg),
        .rf_we(rf_we), .rf_waddr(rf_waddr), .rf_wdata(rf_wdata)
    );

    rv32_hazard hazard_inst (
        .id_rs1(id_rs1), .id_rs2(id_rs2), .id_ex_reg(id_ex_reg),
        .ex_branch_taken(ex_branch_taken), .ex_jump_taken(ex_jump_taken),
        .if_bus_stall(if_bus_stall), .mem_bus_stall(mem_bus_stall),
        .global_stall(global_stall), .stall_if(stall_if), .stall_id(stall_id),
        .flush_if_id(flush_if_id), .flush_id_ex(flush_id_ex)
    );

    rv32_forward forward_inst (
        .ex_rs1(id_ex_reg.rs1), .ex_rs2(id_ex_reg.rs2),
        .ex_mem_reg(ex_mem_reg), .mem_wb_reg(mem_wb_reg),
        .forward_a(forward_a), .forward_b(forward_b)
    );

endmodule
