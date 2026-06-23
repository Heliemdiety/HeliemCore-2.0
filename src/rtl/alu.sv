import rv32_pkg::*;

module rv32_alu (
    input  word_t   a,
    input  word_t   b,
    input  alu_op_e op,
    output word_t   result,
    output logic    zero,
    output logic    less_signed,
    output logic    less_unsigned
);

    // Internal wires for parallel math
    word_t diff_ab;
    word_t diff_ba;
    logic  cmp_u;
    logic  cmp_s;

    always_comb begin
        
        // 1. PARALLEL COMPUTE EVERYTHING

        diff_ab = a - b;
        diff_ba = b - a;                             // Parallel reverse-subtraction for ADIFF
        cmp_u   = (a < b);                           // Dedicated unsigned comparator
        cmp_s   = ($signed(a) < $signed(b));         // Dedicated signed comparator

       
        // 2. FLAT MULTIPLEXER (1-Level Deep)

        unique case (op)
            ALU_ADD:   result = a + b;
            ALU_SUB:   result = diff_ab;
            ALU_SLL:   result = a << b[4:0];
            ALU_SLT:   result = {31'b0, cmp_s};
            ALU_SLTU:  result = {31'b0, cmp_u};
            ALU_XOR:   result = a ^ b;
            ALU_SRL:   result = a >> b[4:0];
            ALU_SRA:   result = $signed(a) >>> b[4:0];
            ALU_OR:    result = a | b;
            ALU_AND:   result = a & b;
            ALU_COPYB: result = b;
            
            // --- Custom Graph Instructions Optimized ---
            // UMIN uses the parallel unsigned comparator directly
            ALU_UMIN:  result = cmp_u ? a : b;
            
            // ADIFF uses the parallel reverse-subtraction. No series math.
            ALU_ADIFF: result = diff_ab[31] ? diff_ba : diff_ab;
            
            default:   result = '0;
        endcase
    end

    
    // 3. Flags 

    assign zero          = (diff_ab == '0);
    assign less_signed   = cmp_s;
    assign less_unsigned = cmp_u;

endmodule