import rv32_pkg::*;

module rv32_imem #(
    parameter MEM_DEPTH = 1024, // 1024 words = 4 Kilobytes
    parameter INIT_FILE = ""    // Path to the compiled .hex file
)(
    input  word_t addr,
    output word_t inst
);

    // The ROM array
    word_t rom [0:MEM_DEPTH-1];

    // Load the program into memory during simulation/synthesis
    initial begin
        // Initialize to NOPs (ADD x0, x0, x0 = 0x00000033)
        for (int i = 0; i < MEM_DEPTH; i++) begin
            rom[i] = 32'h00000033; 
        end
        // If a file is provided, overwrite the NOPs with actual code
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, rom);
        end
    end

    // Asynchronous Read (Combinational)
    // The Program Counter (addr) is byte-addressable (0, 4, 8, C).
    // Our array is word-addressable (0, 1, 2, 3). So we shift right by 2 (divide by 4).
    word_t word_addr;
    assign word_addr = {2'b00, addr[31:2]};

    // Prevent out-of-bounds reading
    assign inst = (word_addr < MEM_DEPTH) ? rom[word_addr] : 32'h00000033; // Default NOP

endmodule