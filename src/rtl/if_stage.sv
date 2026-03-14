import rv32_pkg::*;

module rv32_fetch (
    input  logic  clk,
    input  logic  rst_n,

    // Control signals from Hazard & Execute stages
    input  logic  stall_if,
    input  logic  ex_branch_taken,
    input  logic  ex_jump_taken,
    input  word_t ex_target_addr,

    // Outputs to Instruction Memory & ID Stage
    output word_t pc,
    output word_t pc_plus_4
);

    word_t pc_reg;
    word_t next_pc;

    // --- PC Register (Synchronous) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h00000000; // Boot Address (Reset vector)
        end else begin
            pc_reg <= next_pc;
        end
    end

    // --- Next PC Multiplexer (Combinational) ---
    always_comb begin
        pc_plus_4 = pc_reg + 32'd4;

        // Priority 1: Branches and Jumps override everything
        if (ex_branch_taken || ex_jump_taken) begin
            next_pc = ex_target_addr;
        end 
        // Priority 2: Stalls freeze the PC
        else if (stall_if) begin
            next_pc = pc_reg;
        end 
        // Priority 3: Normal execution (PC + 4)
        else begin
            next_pc = pc_plus_4;
        end
    end

    // Drive output
    assign pc = pc_reg;

endmodule