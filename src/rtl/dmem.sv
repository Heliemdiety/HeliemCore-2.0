import rv32_pkg::*;

module rv32_dmem #(
    parameter MEM_DEPTH = 1024 // 1024 words = 4 Kilobytes
)(
    input  logic       clk,
    
    // Interface from MEM Stage
    input  word_t      addr,
    input  word_t      wdata,
    input  logic       wen,
    input  logic       ren,
    input  logic [3:0] strb,   // Byte Enables
    
    output word_t      rdata
);

    // The RAM array
    word_t ram [0:MEM_DEPTH-1];
    word_t word_addr;
    
    // Address divided by 4 for word-alignment
    assign word_addr = {2'b00, addr[31:2]};

    // --- SYNCHRONOUS WRITE ---
    always_ff @(posedge clk) begin
        if (wen && (word_addr < MEM_DEPTH)) begin
            // Byte-enable masking. Overwrite only the requested bytes!
            if (strb[0]) ram[word_addr][7:0]   <= wdata[7:0];
            if (strb[1]) ram[word_addr][15:8]  <= wdata[15:8];
            if (strb[2]) ram[word_addr][23:16] <= wdata[23:16];
            if (strb[3]) ram[word_addr][31:24] <= wdata[31:24];
        end
    end

    // --- ASYNCHRONOUS READ ---
    // Reads instantly as soon as the address arrives from the EX/MEM register
    always_comb begin
        if (ren && (word_addr < MEM_DEPTH)) begin
            rdata = ram[word_addr];
        end else begin
            rdata = '0;
        end
    end

endmodule