package rv32_pkg;

    // --- Basic Types ---
    typedef logic [31:0] word_t;
    typedef logic [4:0]  reg_addr_t;

    // --- Instruction Opcodes (opcode_e) ---
    typedef enum logic [6:0] {
        OP_LUI      = 7'b0110111,
        OP_AUIPC    = 7'b0010111,
        OP_JAL      = 7'b1101111,
        OP_JALR     = 7'b1100111,
        OP_BRANCH   = 7'b1100011,
        OP_LOAD     = 7'b0000011,
        OP_STORE    = 7'b0100011,
        OP_IMM      = 7'b0010011,
        OP_REG      = 7'b0110011,
        OP_CUSTOM_0 = 7'b0001011 // UMIN and ADIFF
    } opcode_e;

    // --- ALU Operations (alu_op_e) ---
    typedef enum logic [3:0] {
        ALU_ADD   = 4'b0000,
        ALU_SUB   = 4'b0001,
        ALU_SLL   = 4'b0010,
        ALU_SLT   = 4'b0011,
        ALU_SLTU  = 4'b0100,
        ALU_XOR   = 4'b0101,
        ALU_SRL   = 4'b0110,
        ALU_SRA   = 4'b0111,
        ALU_OR    = 4'b1000,
        ALU_AND   = 4'b1001,
        ALU_COPYB = 4'b1010, // Pass Operand B through
        ALU_UMIN  = 4'b1100, // Unsigned Minimum (Custom)
        ALU_ADIFF = 4'b1101  // Absolute Difference (Custom)
    } alu_op_e;

    // --- Pipeline Control Signals (control_t) ---
    typedef struct packed {
        logic       reg_write;
        logic [1:0] wb_sel;     // 00: ALU, 01: Mem, 10: PC+4
        logic       mem_read;
        logic       mem_write;
        logic [2:0] mem_size;   
        logic       is_branch;
        logic       is_jump;    
        alu_op_e    alu_op;
        logic       alu_src_a;  // 0: rs1, 1: PC
        logic       alu_src_b;  // 0: rs2, 1: Imm
    } control_t;

    // --- Pipeline Register Structs ---
    
    typedef struct packed {
        word_t pc;
        word_t inst;
    } if_id_t;

    typedef struct packed {
        word_t     pc;
        word_t     imm;
        word_t     rs1_data;
        word_t     rs2_data;
        reg_addr_t rs1;
        reg_addr_t rs2;
        reg_addr_t rd;
        logic [2:0] funct3;     // Passed down for branch evaluation
        control_t  ctrl;
    } id_ex_t;

    typedef struct packed {
        word_t     alu_result;
        word_t     rs2_data;    // Store data (used by Memory stage)
        reg_addr_t rd;
        control_t  ctrl;
    } ex_mem_t;

    typedef struct packed {
        word_t     alu_result;
        word_t     mem_read_data;
        word_t     pc_plus_4;   // For JAL/JALR Writeback
        reg_addr_t rd;
        control_t  ctrl;
    } mem_wb_t;

endpackage