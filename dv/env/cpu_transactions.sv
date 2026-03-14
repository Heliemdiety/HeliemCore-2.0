// -----------------------------------------------------------------------------
// In UVM, we don't think about 1s and 0s. We think about "Objects".
// This object represents a single instruction moving through your CPU.
// -----------------------------------------------------------------------------
import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_transaction extends uvm_sequence_item;

    // -------------------------------------------------------------------------
    // PHYSICAL DATA (Sampled from the CPU)
    // -------------------------------------------------------------------------
    logic [31:0] pc;
    logic [31:0] inst;
    logic        rf_we;
    logic [4:0]  rf_waddr;
    logic [31:0] rf_wdata;

    // -------------------------------------------------------------------------
    // UVM FACTORY REGISTRATION
    // -------------------------------------------------------------------------
    `uvm_object_utils_begin(cpu_transaction)
        `uvm_field_int(pc,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(inst,     UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(rf_we,    UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(rf_waddr, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(rf_wdata, UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "cpu_transaction");
        super.new(name);
    endfunction

    // Helper function to print beautifully in the console
    virtual function string convert2string();
        return $sformatf("PC: 0x%0h | Inst: 0x%0h | RegWrite: %0b | DestReg: x%0d | WriteData: 0x%0h", 
                         pc, inst, rf_we, rf_waddr, rf_wdata);
    endfunction

endclass