import rv32_pkg::*;

module rv32_hazard (
    input  reg_addr_t id_rs1,
    input  reg_addr_t id_rs2,
    input  id_ex_t    id_ex_reg,
    input  logic      ex_branch_taken,
    input  logic      ex_jump_taken,

    // Bus stalls from AXI
    input  logic      if_bus_stall,
    input  logic      mem_bus_stall,

    // Outputs
    output logic      global_stall,  // Freezes entire pipeline
    output logic      stall_if,
    output logic      stall_id,
    output logic      flush_if_id,
    output logic      flush_id_ex
);

    always_comb begin
        stall_if     = 1'b0;
        stall_id     = 1'b0;
        flush_if_id  = 1'b0;
        flush_id_ex  = 1'b0;
        global_stall = 1'b0;

       
        // 1. AXI Bus Stalls (Highest Priority - Freezes EVERYTHING)
        if (if_bus_stall || mem_bus_stall) begin
            global_stall = 1'b1;
            // The top module will use global_stall to disable all pipeline flip-flops.
        end

        // 2. Control Hazard Detection (Branch/Jump Taken)
        else if (ex_branch_taken || ex_jump_taken) begin
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end
        
        // 3. Load-Use Hazard Detection
        else if (id_ex_reg.ctrl.mem_read && (id_ex_reg.rd != 5'd0) && 
           ((id_ex_reg.rd == id_rs1) || (id_ex_reg.rd == id_rs2))) begin
            stall_if    = 1'b1;
            stall_id    = 1'b1;
            flush_id_ex = 1'b1;
        end
    end

endmodule
