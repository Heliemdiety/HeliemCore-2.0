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
    // -------------------------------------------------------------------------
    // THE BULLETPROOF FIRMWARE INJECTION (Dijkstra Custom Kernel)
    // -------------------------------------------------------------------------
    initial begin
        // 1. ADDI x1, x0, 20 (Load a distance of 20)
        uut.imem_inst.rom[0]  = 32'h01400093; 
        
        // 2. ADDI x2, x0, 50 (Load a distance of 50)
        uut.imem_inst.rom[1]  = 32'h03200113; 
        
        // 3. ADIFF x3, x1, x2 (Should calculate |20 - 50| = 30)
        // OP=0001011, rd=00011 (x3), funct3=001, rs1=00001 (x1), rs2=00010 (x2), funct7=0000000
        uut.imem_inst.rom[2]  = 32'h0020918b; 
        
        // 4. UMIN x4, x1, x2 (Should pick Min(20, 50) = 20)
        // OP=0001011, rd=00100 (x4), funct3=000, rs1=00001 (x1), rs2=00010 (x2), funct7=0000000
        uut.imem_inst.rom[3]  = 32'h0020820b; 
        
        // 5. JAL x0, 0 (Infinite Loop to end program)
        uut.imem_inst.rom[4]  = 32'h0000006f; 
        
        // Fill the rest with NOPs just to be clean
        for(int i=5; i<64; i++) uut.imem_inst.rom[i] = 32'h00000033;
        
        $display("UVM TB: Dijkstra Custom Kernel Firmware loaded successfully.");
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