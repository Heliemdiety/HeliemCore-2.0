import rv32_pkg::*;

module rv32_execute (
    // The giant struct containing everything from the Decode stage
    input  id_ex_t     id_ex_reg,

    // Forwarding inputs from later pipeline stages
    input  logic [1:0] forward_a,
    input  logic [1:0] forward_b,
    input  word_t      forward_ex_data,  // Data from EX/MEM
    input  word_t      forward_mem_data, // Data from MEM/WB

    // Outputs to the IF Stage (Control Flow)
    output logic       ex_branch_taken,
    output logic       ex_jump_taken,
    output word_t      ex_target_addr,

    // The giant struct passing to the Memory stage
    output ex_mem_t    ex_mem_data
);

    word_t op_a_fwd;
    word_t op_b_fwd;
    word_t alu_in_a;
    word_t alu_in_b;
    word_t alu_result;
    logic  zero, less_signed, less_unsigned;
    logic  branch_condition_met;

    // 1. Data Forwarding Multiplexers
    always_comb begin
        // Operand A Forwarding
        case (forward_a)
            2'b01: op_a_fwd = forward_ex_data;
            2'b10: op_a_fwd = forward_mem_data;
            default: op_a_fwd = id_ex_reg.rs1_data;
        endcase

        // Operand B Forwarding
        case (forward_b)
            2'b01: op_b_fwd = forward_ex_data;
            2'b10: op_b_fwd = forward_mem_data;
            default: op_b_fwd = id_ex_reg.rs2_data;
        endcase
    end

    // 2. ALU Input Multiplexers
    // src_a == 1 ? PC : Forwarded rs1
    assign alu_in_a = (id_ex_reg.ctrl.alu_src_a) ? id_ex_reg.pc  : op_a_fwd;
    // src_b == 1 ? Immediate : Forwarded rs2
    assign alu_in_b = (id_ex_reg.ctrl.alu_src_b) ? id_ex_reg.imm : op_b_fwd;


    // 3. The ALU
    rv32_alu alu_inst (
        .a(alu_in_a),
        .b(alu_in_b),
        .op(id_ex_reg.ctrl.alu_op),
        .result(alu_result),
        .zero(zero),
        .less_signed(less_signed),
        .less_unsigned(less_unsigned)
    );

    // 4. Branch Evaluation Logic
    always_comb begin
        case (id_ex_reg.funct3)
            3'b000: branch_condition_met = zero;             // BEQ
            3'b001: branch_condition_met = !zero;            // BNE
            3'b100: branch_condition_met = less_signed;      // BLT
            3'b101: branch_condition_met = !less_signed;     // BGE
            3'b110: branch_condition_met = less_unsigned;    // BLTU
            3'b111: branch_condition_met = !less_unsigned;   // BGEU
            default: branch_condition_met = 1'b0;
        endcase
    end

    assign ex_branch_taken = id_ex_reg.ctrl.is_branch & branch_condition_met;
    assign ex_jump_taken   = id_ex_reg.ctrl.is_jump;


    // 5. Target Address Calculation (Branch / JAL / JALR)
    always_comb begin
        // JALR sets alu_src_b=1 in the decoder. The ALU naturally calculates rs1 + imm.
        // The RISC-V spec requires setting the LSB of JALR target to 0.
        if (id_ex_reg.ctrl.is_jump && id_ex_reg.ctrl.alu_src_b == 1'b1) begin
            ex_target_addr = alu_result & 32'hFFFFFFFE; 
        end else begin
            // Standard Branches and JAL use PC + Immediate
            ex_target_addr = id_ex_reg.pc + id_ex_reg.imm;
        end
    end

    // 6. Package the data for the next stage (MEM)
    always_comb begin
        ex_mem_data.alu_result = alu_result;
        // We pass the forwarded rs2 data down because the Store instruction needs it!
        ex_mem_data.rs2_data   = op_b_fwd; 
        ex_mem_data.rd         = id_ex_reg.rd;
        ex_mem_data.ctrl       = id_ex_reg.ctrl;
    end

endmodule
