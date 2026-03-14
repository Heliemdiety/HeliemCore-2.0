import rv32_pkg::*; // Uses the package we defined earlier!

module rv32_regfile (
    input  logic      clk,
    input  logic      rst_n,

    // Read Ports (Combinational)
    input  logic [4:0] rs1_addr,
    input  logic [4:0] rs2_addr,
    output word_t      rs1_data,
    output word_t      rs2_data,

    // Write Port (Synchronous)
    input  logic       write_en,
    input  logic [4:0] write_addr,
    input  word_t      write_data
);

    // The actual 32 registers in hardware
    word_t registers [0:31];

    // --- SYNCHRONOUS WRITE ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= '0;
            end
        end else begin
            // Only write if Enable is HIGH and Address is NOT x0 (0)
            if (write_en && write_addr != 5'd0) begin
                registers[write_addr] <= write_data;
            end
        end
    end

    // --- COMBINATIONAL READ WITH INTERNAL FORWARDING ---
    always_comb begin
        // Port 1 Read
        if (rs1_addr == 5'd0) begin
            rs1_data = '0; // x0 is always 0
        end else if (write_en && (write_addr == rs1_addr)) begin
            rs1_data = write_data; // Write-First Forwarding
        end else begin
            rs1_data = registers[rs1_addr];
        end

        // Port 2 Read
        if (rs2_addr == 5'd0) begin
            rs2_data = '0; // x0 is always 0
        end else if (write_en && (write_addr == rs2_addr)) begin
            rs2_data = write_data; // Write-First Forwarding
        end else begin
            rs2_data = registers[rs2_addr];
        end
    end

endmodule