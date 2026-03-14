import rv32_pkg::*;

module rv32_immgen (
    input  word_t inst,
    output word_t imm
);

    opcode_e opcode;
    assign opcode = opcode_e'(inst[6:0]);

    always_comb begin
        // Default to 0 (Used for R-Type, UMIN, ADIFF)
        imm = '0; 

        unique case (opcode)
            // -----------------------------------------------------------------
            // I-Type (Loads, Immediate Arithmetic, JALR)
            // Immediate is in inst[31:20]
            // -----------------------------------------------------------------
            OP_IMM, OP_LOAD, OP_JALR: begin
                imm = { {20{inst[31]}}, inst[31:20] };
            end

            // -----------------------------------------------------------------
            // S-Type (Stores)
            // Immediate is split: inst[31:25] and inst[11:7]
            // -----------------------------------------------------------------
            OP_STORE: begin
                imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };
            end

            // -----------------------------------------------------------------
            // B-Type (Branches)
            // Immediate is scrambled and multiplied by 2 (implicit 0 at the end)
            // -----------------------------------------------------------------
            OP_BRANCH: begin
                imm = { {19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0 };
            end

            // -----------------------------------------------------------------
            // U-Type (LUI, AUIPC)
            // Immediate is in the top 20 bits. Bottom 12 bits are 0.
            // -----------------------------------------------------------------
            OP_LUI, OP_AUIPC: begin
                imm = { inst[31:12], 12'b0 };
            end

            // -----------------------------------------------------------------
            // J-Type (JAL)
            // Immediate is scrambled and multiplied by 2 (implicit 0 at the end)
            // -----------------------------------------------------------------
            OP_JAL: begin
                imm = { {11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0 };
            end

            // OP_REG and OP_CUSTOM_0 fall into the default (0)
            default: imm = '0;   //The answer is: R-Type instructions do not have immediate values! Think about a standard R-Type instruction like ADD x1, x2, x3. It uses three registers (rs1, rs2, and rd). There is absolutely no space left in the 32-bit instruction word to cram a constant number (an immediate) into it.Because they don't use immediates, our ImmGen module doesn't need to extract anything for them.
        endcase
    end

endmodule