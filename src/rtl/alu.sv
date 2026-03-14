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

    word_t diff;
    logic  is_negative;

    always_comb begin
        // Compute standard difference once (reused by SUB, SLT, and ADIFF)
        diff = a - b;
        is_negative = diff[31];

        // Default output
        result = '0;

        unique case (op)
            ALU_ADD:   result = a + b;
            ALU_SUB:   result = diff;
            ALU_SLL:   result = a << b[4:0];
            ALU_SLT:   result = {31'b0, ($signed(a) < $signed(b))};
            ALU_SLTU:  result = {31'b0, (a < b)};
            ALU_XOR:   result = a ^ b;
            ALU_SRL:   result = a >> b[4:0];
            ALU_SRA:   result = $signed(a) >>> b[4:0];
            ALU_OR:    result = a | b;
            ALU_AND:   result = a & b;
            ALU_COPYB: result = b;
            
            // --- Custom Graph Instructions ---
            // UMIN: Unsigned Minimum
            ALU_UMIN:  result = (a < b) ? a : b;
            
            // ADIFF: Absolute Difference
            // If diff is negative, take 2's complement (~diff + 1)
            ALU_ADIFF: result = is_negative ? (~diff + 1'b1) : diff;
            
            default:   result = '0;
        endcase
    end

    // Flags used by the Branch unit later
    assign zero          = (diff == '0);
    assign less_signed   = ($signed(a) < $signed(b));
    assign less_unsigned = (a < b);

endmodule