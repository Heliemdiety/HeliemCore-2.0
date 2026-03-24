import rv32_pkg::*;

module rv32_fetch (
    input  logic  clk,
    input  logic  rst_n,

    // Control signals from Hazard & Execute stages
    input  logic  global_stall,    // Global AXI Freeze
    input  logic  stall_if,
    input  logic  ex_branch_taken,
    input  logic  ex_jump_taken,
    input  word_t ex_target_addr,

    // Outputs to Pipeline
    output word_t pc,
    output word_t pc_plus_4,
    output word_t fetched_inst,    // Passes the final instruction to ID stage

    // AXI IFETCH BIU Handshake
    output word_t cpu_req_addr,
    output logic  cpu_req_valid,
    input  logic  cpu_req_ready,
    input  word_t cpu_instr_out,
    input  logic  cpu_instr_valid,

    // Output to Hazard Unit
    output logic  if_bus_stall
);

    word_t pc_reg;
    word_t next_pc;

    // PC Register 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h00000000;
        end else if (!global_stall) begin // ONLY advance if the bus is NOT stalled
            pc_reg <= next_pc;
        end
    end

    // Next PC Logic
    always_comb begin
        pc_plus_4 = pc_reg + 32'd4;
        if (ex_branch_taken || ex_jump_taken) next_pc = ex_target_addr;
        else if (stall_if)                    next_pc = pc_reg;
        else                                  next_pc = pc_plus_4;
    end

    // AXI BIU Connection 
    assign pc           = pc_reg;
    assign cpu_req_addr = pc_reg;
    assign cpu_req_valid= 1'b1; // We always want to fetch

    // The Catcher Mitt Latch 
    // If the instruction arrives, but the pipeline is frozen by a D-MEM stall,  we must catch the instruction and hold it so it doesn't disappear.
    logic [31:0] latched_inst;
    logic        latched_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_valid <= 1'b0;
            latched_inst  <= 32'h0;
        end else begin
            if (ex_branch_taken || ex_jump_taken) begin
                latched_valid <= 1'b0; // Throw away caught instruction on a branch flush
            end else if (cpu_instr_valid && global_stall) begin
                latched_inst  <= cpu_instr_out;
                latched_valid <= 1'b1; 
            end else if (!global_stall) begin
                latched_valid <= 1'b0; 
            end
        end
    end

    // Feed the pipeline either the live AXI data or our caught data
    assign fetched_inst = latched_valid ? latched_inst : cpu_instr_out;
    
    // Tell the Hazard Unit to stall the CPU if we don't have an instruction ready
    assign if_bus_stall = !(cpu_instr_valid || latched_valid);

endmodule
