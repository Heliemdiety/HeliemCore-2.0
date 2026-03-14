import rv32_pkg::*;

module rv32_writeback (
    // Input from the MEM/WB Pipeline Register
    input  mem_wb_t   mem_wb_reg,

    // Outputs to the Register File
    output logic      rf_we,
    output reg_addr_t rf_waddr,
    output word_t     rf_wdata
);

    // Pass through Write Enable and Destination Address
    assign rf_we    = mem_wb_reg.ctrl.reg_write;
    assign rf_waddr = mem_wb_reg.rd;

    // The Writeback Multiplexer
    always_comb begin
        case (mem_wb_reg.ctrl.wb_sel)
            2'b00:   rf_wdata = mem_wb_reg.alu_result;     // Arithmetic / Custom logic
            2'b01:   rf_wdata = mem_wb_reg.mem_read_data;  // Loads
            2'b10:   rf_wdata = mem_wb_reg.pc_plus_4;      // Jumps
            default: rf_wdata = '0;                        // Safe default
        endcase
    end

endmodule