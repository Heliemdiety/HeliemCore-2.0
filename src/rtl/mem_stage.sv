import rv32_pkg::*;

module rv32_memory (
    // Inputs from EX/MEM Pipeline Register
    input  ex_mem_t ex_mem_reg,
    input  word_t   ex_mem_pc_plus_4, // Piped alongside the struct

    // Data Memory Interface (To actual RAM)
    output word_t      dmem_addr,
    output word_t      dmem_wdata,
    output logic       dmem_wen,
    output logic       dmem_ren,
    output logic [3:0] dmem_strb,     // Byte Enables

    // Data from Data Memory
    input  word_t      dmem_rdata,

    // Output to MEM/WB Pipeline Register
    output mem_wb_t    mem_wb_data
);

    logic [1:0] addr_align;
    assign addr_align = ex_mem_reg.alu_result[1:0];

    // Block RAMs need word-aligned addresses (Bottom 2 bits are 0)
    assign dmem_addr = {ex_mem_reg.alu_result[31:2], 2'b00}; 
    assign dmem_ren  = ex_mem_reg.ctrl.mem_read;
    assign dmem_wen  = ex_mem_reg.ctrl.mem_write;

    // -------------------------------------------------------------------------
    // 1. Store Data Alignment & Strobes
    // -------------------------------------------------------------------------
    always_comb begin
        // Default values
        dmem_wdata = ex_mem_reg.rs2_data;
        dmem_strb  = 4'b0000;

        if (ex_mem_reg.ctrl.mem_write) begin
            case (ex_mem_reg.ctrl.mem_size)
                3'b000: begin // SB (Store Byte)
                    // Duplicate the byte 4 times. The strobe selects the right one!
                    dmem_wdata = {4{ex_mem_reg.rs2_data[7:0]}};
                    dmem_strb  = 4'b0001 << addr_align;
                end
                3'b001: begin // SH (Store Halfword)
                    // Duplicate the halfword 2 times.
                    dmem_wdata = {2{ex_mem_reg.rs2_data[15:0]}};
                    dmem_strb  = 4'b0011 << addr_align;
                end
                3'b010: begin // SW (Store Word)
                    dmem_strb  = 4'b1111;
                end
                default: dmem_strb = 4'b0000;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 2. Load Data Extraction & Extension
    // -------------------------------------------------------------------------
    word_t       formatted_rdata;
    logic [7:0]  byte_read;
    logic [15:0] half_read;

    always_comb begin
        // Extract the correct byte based on the address offset
        case (addr_align)
            2'b00: byte_read = dmem_rdata[7:0];
            2'b01: byte_read = dmem_rdata[15:8];
            2'b10: byte_read = dmem_rdata[23:16];
            2'b11: byte_read = dmem_rdata[31:24];
        endcase

        // Extract the correct halfword
        case (addr_align[1])
            1'b0: half_read = dmem_rdata[15:0];
            1'b1: half_read = dmem_rdata[31:16];
        endcase

        // Format data based on instruction (Sign/Zero Extend)
        case (ex_mem_reg.ctrl.mem_size)
            3'b000: formatted_rdata = { {24{byte_read[7]}}, byte_read };      // LB  (Sign Extend)
            3'b001: formatted_rdata = { {16{half_read[15]}}, half_read };     // LH  (Sign Extend)
            3'b010: formatted_rdata = dmem_rdata;                             // LW  (Full Word)
            3'b100: formatted_rdata = { 24'b0, byte_read };                   // LBU (Zero Extend)
            3'b101: formatted_rdata = { 16'b0, half_read };                   // LHU (Zero Extend)
            default: formatted_rdata = dmem_rdata;
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. Package the data for Writeback (WB) Stage
    // -------------------------------------------------------------------------
    always_comb begin
        mem_wb_data.alu_result    = ex_mem_reg.alu_result;
        mem_wb_data.mem_read_data = formatted_rdata;
        mem_wb_data.pc_plus_4     = ex_mem_pc_plus_4;
        mem_wb_data.rd            = ex_mem_reg.rd;
        mem_wb_data.ctrl          = ex_mem_reg.ctrl;
    end

endmodule