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


    // 1 & 2. Unified Flattened ALU Input Multiplexers
    always_comb begin
        // Operand A 
        if (id_ex_reg.ctrl.alu_src_a) alu_in_a = id_ex_reg.pc;
        else if (forward_a == 2'b01)  alu_in_a = forward_ex_data;
        else if (forward_a == 2'b10)  alu_in_a = forward_mem_data;
        else                          alu_in_a = id_ex_reg.rs1_data;

        // Operand B
        if (id_ex_reg.ctrl.alu_src_b) alu_in_b = id_ex_reg.imm;
        else if (forward_b == 2'b01)  alu_in_b = forward_ex_data;
        else if (forward_b == 2'b10)  alu_in_b = forward_mem_data;
        else                          alu_in_b = id_ex_reg.rs2_data;
        
        op_a_fwd = (forward_a == 2'b01) ? forward_ex_data : 
                   (forward_a == 2'b10) ? forward_mem_data : id_ex_reg.rs1_data;
                   
        op_b_fwd = (forward_b == 2'b01) ? forward_ex_data : 
                   (forward_b == 2'b10) ? forward_mem_data : id_ex_reg.rs2_data;
    end

    
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
            3'b000: branch_condition_met = (op_a_fwd == op_b_fwd);                  // BEQ
            3'b001: branch_condition_met = (op_a_fwd != op_b_fwd);                  // BNE
            3'b100: branch_condition_met = ($signed(op_a_fwd) < $signed(op_b_fwd)); // BLT
            3'b101: branch_condition_met = ($signed(op_a_fwd) >= $signed(op_b_fwd));// BGE
            3'b110: branch_condition_met = (op_a_fwd < op_b_fwd);                   // BLTU
            3'b111: branch_condition_met = (op_a_fwd >= op_b_fwd);                  // BGEU
            default: branch_condition_met = 1'b0;
        endcase
    end

    assign ex_branch_taken = id_ex_reg.ctrl.is_branch & branch_condition_met;
    assign ex_jump_taken   = id_ex_reg.ctrl.is_jump;


    // 5. Target Address Calculation (Branch / JAL / JALR)
    word_t branch_jal_target;
    word_t jalr_target;

    assign branch_jal_target = id_ex_reg.pc + id_ex_reg.imm;
    // The RISC-V spec requires setting the LSB of JALR target to 0.
    assign jalr_target       = (op_a_fwd + id_ex_reg.imm) & 32'hFFFFFFFE; 

    always_comb begin
        if (id_ex_reg.ctrl.is_jump && id_ex_reg.ctrl.alu_src_b == 1'b1) begin
            ex_target_addr = jalr_target;
        end else begin
            ex_target_addr = branch_jal_target; 
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