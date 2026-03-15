import rv32_pkg::*;

module rv32_hazard (
    // Inputs from ID Stage 
    input  reg_addr_t id_rs1,
    input  reg_addr_t id_rs2,
    
    // Spying on the EX Stage
    input  id_ex_t    id_ex_reg,
    input  logic      ex_branch_taken,
    input  logic      ex_jump_taken,

    // Outputs to Pipeline Registers
    output logic      stall_if,      // Freezes PC
    output logic      stall_id,      // Freezes IF/ID register
    output logic      flush_if_id,   // Clears IF/ID register
    output logic      flush_id_ex    // Clears ID/EX register (Inserts Bubble)
);

    always_comb begin
        // Default: Pipeline flows normally
        stall_if    = 1'b0;
        stall_id    = 1'b0;
        flush_if_id = 1'b0;
        flush_id_ex = 1'b0;

        
        // 1. Load-Use Hazard Detection
        // If EX is reading memory, AND its destination matches our sources...
        if (id_ex_reg.ctrl.mem_read && (id_ex_reg.rd != 5'd0) && 
           ((id_ex_reg.rd == id_rs1) || (id_ex_reg.rd == id_rs2))) begin
            stall_if    = 1'b1; // Stop fetching new instructions
            stall_id    = 1'b1; // Keep current instruction in ID stage
            flush_id_ex = 1'b1; // Insert a bubble (NOP) into the EX stage
        end

        // 2. Control Hazard Detection (Branch/Jump Taken)
        // Overrides Load-Use hazards! If we branch, we must flush the pipeline
        // to achieve the 2-cycle penalty.

        if (ex_branch_taken || ex_jump_taken) begin
            stall_if    = 1'b0; 
            stall_id    = 1'b0; 
            flush_if_id = 1'b1; // Flush the instruction in the ID stage
            flush_id_ex = 1'b1; // Flush the instruction entering the EX stage
        end
    end

endmodule
