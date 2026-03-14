// -----------------------------------------------------------------------------
// This Interface is the physical bridge between the UVM world (Software) 
// and your RISC-V CPU (Hardware). 
// -----------------------------------------------------------------------------
interface cpu_if (input logic clk);
    
    // Core control
    logic rst_n;

    // -------------------------------------------------------------------------
    // PASSIVE MONITORS (Spying on the CPU internal state)
    // -------------------------------------------------------------------------
    // To verify a CPU, UVM needs to see what instructions are executing 
    // and what the CPU is writing back to the Register File.
    
    // IF Stage Spies
    logic [31:0] pc;
    logic [31:0] inst;

    // WB Stage Spies (To check if the math was right!)
    logic        rf_we;
    logic [4:0]  rf_waddr;
    logic [31:0] rf_wdata;

    // We use clocking blocks to ensure UVM samples data without race conditions
    clocking monitor_cb @(posedge clk);
        default input #1step output #1ns;
        input pc;
        input inst;
        input rf_we;
        input rf_waddr;
        input rf_wdata;
    endclocking

endinterface