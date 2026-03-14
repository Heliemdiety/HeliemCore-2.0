
// -----------------------------------------------------------------------------
// MODULE DEFINITION
// -----------------------------------------------------------------------------
import rv32_pkg::*;

module instruction_decoder (
    input  word_t    inst,
    output control_t ctrl
);

    opcode_e opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = opcode_e'(inst[6:0]);
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];

    always_comb begin
        // Default safe state (NOP)
        ctrl.reg_write = 1'b0;
        ctrl.wb_sel    = 2'b00;     
        ctrl.mem_read  = 1'b0;
        ctrl.mem_write = 1'b0;
        ctrl.mem_size  = funct3;    
        ctrl.is_branch = 1'b0;
        ctrl.is_jump   = 1'b0;
        ctrl.alu_op    = ALU_ADD;
        ctrl.alu_src_a = 1'b0;      
        ctrl.alu_src_b = 1'b0;      

        unique case (opcode)
            OP_REG: begin
                ctrl.reg_write = 1'b1;
                unique case ({funct7, funct3})
                    10'b0000000_000: ctrl.alu_op = ALU_ADD;
                    10'b0100000_000: ctrl.alu_op = ALU_SUB;
                    10'b0000000_001: ctrl.alu_op = ALU_SLL;
                    10'b0000000_010: ctrl.alu_op = ALU_SLT;
                    10'b0000000_011: ctrl.alu_op = ALU_SLTU;
                    10'b0000000_100: ctrl.alu_op = ALU_XOR;
                    10'b0000000_101: ctrl.alu_op = ALU_SRL;
                    10'b0100000_101: ctrl.alu_op = ALU_SRA;
                    10'b0000000_110: ctrl.alu_op = ALU_OR;
                    10'b0000000_111: ctrl.alu_op = ALU_AND;
                    default:         ctrl.alu_op = ALU_ADD;
                endcase
            end

            OP_IMM: begin
                ctrl.reg_write = 1'b1;
                ctrl.alu_src_b = 1'b1; 
                unique case (funct3)
                    3'b000: ctrl.alu_op = ALU_ADD;
                    3'b010: ctrl.alu_op = ALU_SLT;
                    3'b011: ctrl.alu_op = ALU_SLTU;
                    3'b100: ctrl.alu_op = ALU_XOR;
                    3'b110: ctrl.alu_op = ALU_OR;
                    3'b111: ctrl.alu_op = ALU_AND;
                    3'b001: ctrl.alu_op = ALU_SLL;
                    3'b101: ctrl.alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL; 
                    default: ctrl.alu_op = ALU_ADD;
                endcase
            end

            OP_LOAD: begin
                ctrl.reg_write = 1'b1;
                ctrl.mem_read  = 1'b1;
                ctrl.wb_sel    = 2'b01; 
                ctrl.alu_src_b = 1'b1;  
                ctrl.alu_op    = ALU_ADD;
            end

            OP_STORE: begin
                ctrl.mem_write = 1'b1;
                ctrl.alu_src_b = 1'b1;  
                ctrl.alu_op    = ALU_ADD;
            end

            OP_BRANCH: begin
                ctrl.is_branch = 1'b1;
                ctrl.alu_op    = ALU_SUB; // Force SUB so EX stage generates zero/less flags!
            end

            OP_LUI: begin
                ctrl.reg_write = 1'b1;
                ctrl.alu_src_b = 1'b1; 
                ctrl.alu_op    = ALU_COPYB; 
            end

            OP_AUIPC: begin
                ctrl.reg_write = 1'b1;
                ctrl.alu_src_a = 1'b1; 
                ctrl.alu_src_b = 1'b1; 
                ctrl.alu_op    = ALU_ADD; 
            end

            OP_JAL: begin
                ctrl.reg_write = 1'b1;
                ctrl.is_jump   = 1'b1;
                ctrl.wb_sel    = 2'b10; 
            end

            OP_JALR: begin
                ctrl.reg_write = 1'b1;
                ctrl.is_jump   = 1'b1;
                ctrl.wb_sel    = 2'b10; 
                ctrl.alu_src_b = 1'b1;  
                ctrl.alu_op    = ALU_ADD; 
            end

            // --- CUSTOM GRAPH ISA EXTENSION ---
            OP_CUSTOM_0: begin
                ctrl.reg_write = 1'b1;
                unique case (funct3)
                    3'b000: ctrl.alu_op = ALU_UMIN;  
                    3'b001: ctrl.alu_op = ALU_ADIFF; 
                    default: ctrl.alu_op = ALU_ADD;  
                endcase
            end

            default: ; 
        endcase
    end
endmodule