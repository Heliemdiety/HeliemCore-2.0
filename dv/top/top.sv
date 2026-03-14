import uvm_pkg::*;
`include "uvm_macros.svh"
import rv32_pkg::*;
//`include "cpu_transaction.sv"
//`include "cpu_scoreboard.sv"
//`include "cpu_monitor.sv"
//`include "cpu_env.sv"
//`include "cpu_test.sv"

// PULL IN THE UVM CLASSES WITH ABSOLUTE PATHS
// -----------------------------------------------------------------------------
`include "D:/ACTUAL_WORK/senior engineer CPU/UVM/cpu_transactions.sv"
`include "D:/ACTUAL_WORK/senior engineer CPU/UVM/scoreboard.sv"
`include "D:/ACTUAL_WORK/senior engineer CPU/UVM/monitor.sv"
`include "D:/ACTUAL_WORK/senior engineer CPU/UVM/environment.sv"
`include "D:/ACTUAL_WORK/senior engineer CPU/UVM/test.sv"

module tb_uvm_top();

    logic clk;
    logic rst_n;

    // 1. Instantiate the physical interface (The Bridge)
    cpu_if vif(.clk(clk));
    
    // Drive reset from the interface to the design
    assign vif.rst_n = rst_n;

    // 2. Instantiate your actual Hardware CPU
    riscv_core_top uut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // 3. SPY WIRES: Connect the UVM interface strictly to the CPU's internal wires!
    // assign vif.pc       = uut.if_pc;
    // assign vif.inst     = uut.if_inst;
    // assign vif.rf_we    = uut.rf_we;
    // assign vif.rf_waddr = uut.rf_waddr;
    // assign vif.rf_wdata = uut.rf_wdata;

    assign vif.pc       = uut.mem_wb_rvfi_pc;
    assign vif.inst     = uut.mem_wb_rvfi_inst;
    assign vif.rf_we    = uut.rf_we;
    assign vif.rf_waddr = uut.rf_waddr;
    assign vif.rf_wdata = uut.rf_wdata;

    // Clock Generator
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // THE BULLETPROOF FIRMWARE INJECTION
    // Bypassing $readmemh completely just like we did before!
    // -------------------------------------------------------------------------
    initial begin
        uut.imem_inst.rom[0]  = 32'h00000093; // ADDI x1, x0, 0
        uut.imem_inst.rom[1]  = 32'h00100113; // ADDI x2, x0, 1
        uut.imem_inst.rom[2]  = 32'h00c00193; // ADDI x3, x0, 12
        uut.imem_inst.rom[3]  = 32'h00000213; // ADDI x4, x0, 0
        uut.imem_inst.rom[4]  = 32'h00320c63; // BEQ x4, x3, 24
        uut.imem_inst.rom[5]  = 32'h002082b3; // ADD x5, x1, x2
        uut.imem_inst.rom[6]  = 32'h002000b3; // ADD x1, x0, x2
        uut.imem_inst.rom[7]  = 32'h00500133; // ADD x2, x0, x5
        uut.imem_inst.rom[8]  = 32'h00120213; // ADDI x4, x4, 1
        uut.imem_inst.rom[9]  = 32'hfedff06f; // JAL x0, -20
        uut.imem_inst.rom[10] = 32'h0000006f; // JAL x0, 0
        $display("UVM TB: Firmware force-loaded successfully.");
    end

    // Hardware Reset Timeline
    initial begin
        clk = 0;
        rst_n = 0;
        #10 rst_n = 1;
    end

    // -------------------------------------------------------------------------
    // THE UVM BOOTSTRAPPER
    // -------------------------------------------------------------------------
    initial begin
        // Drop the physical 'vif' into the global database so the Monitor can find it!
        uvm_config_db#(virtual cpu_if)::set(null, "*", "vif", vif);

        // Start the UVM framework!
        run_test("base_test");
    end

endmodule