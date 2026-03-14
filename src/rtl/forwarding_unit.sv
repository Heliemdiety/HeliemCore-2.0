import rv32_pkg::*;

module rv32_forward (
    input  reg_addr_t ex_rs1,
    input  reg_addr_t ex_rs2,
    
    // Spying on the pipeline registers ahead of the EX stage
    input  ex_mem_t   ex_mem_reg,
    input  mem_wb_t   mem_wb_reg,

    // 00: From RegFile, 01: Forward from EX/MEM, 10: Forward from MEM/WB
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    always_comb begin
        forward_a = 2'b00; // Default: No forwarding
        forward_b = 2'b00;

        // --- FORWARD A (rs1) ---
        // Priority 1: EX/MEM Hazard (Most recent instruction)
        if (ex_mem_reg.ctrl.reg_write && (ex_mem_reg.rd != 5'd0) && (ex_mem_reg.rd == ex_rs1)) begin
            forward_a = 2'b01;
        end
        // Priority 2: MEM/WB Hazard (Older instruction)
        else if (mem_wb_reg.ctrl.reg_write && (mem_wb_reg.rd != 5'd0) && (mem_wb_reg.rd == ex_rs1)) begin
            forward_a = 2'b10;
        end

        // --- FORWARD B (rs2) ---
        if (ex_mem_reg.ctrl.reg_write && (ex_mem_reg.rd != 5'd0) && (ex_mem_reg.rd == ex_rs2)) begin
            forward_b = 2'b01;
        end
        else if (mem_wb_reg.ctrl.reg_write && (mem_wb_reg.rd != 5'd0) && (mem_wb_reg.rd == ex_rs2)) begin
            forward_b = 2'b10;
        end
    end

endmodule