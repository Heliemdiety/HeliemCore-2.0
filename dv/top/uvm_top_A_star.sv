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
    // THE BULLETPROOF FIRMWARE INJECTION (A* Custom Kernel)
    // -------------------------------------------------------------------------
    initial begin
        // --- SETUP NODE COORDINATES ---
        // 1. ADDI x1, x0, 10   (Node 1 X-coordinate = 10)
        uut.imem_inst.rom[0]  = 32'h00a00093; 
        
        // 2. ADDI x2, x0, 4    (Node 2 X-coordinate = 4)
        uut.imem_inst.rom[1]  = 32'h00400113; 
        
        // 3. ADDI x3, x0, 15   (Node 1 Y-coordinate = 15)
        uut.imem_inst.rom[2]  = 32'h00f00193; 
        
        // 4. ADDI x4, x0, 20   (Node 2 Y-coordinate = 20)
        uut.imem_inst.rom[3]  = 32'h01400213; 
        
        // --- CALCULATE MANHATTAN DISTANCE (h_cost) ---
        // 5. ADIFF x5, x1, x2  (dx = |10 - 4| = 6)
        uut.imem_inst.rom[4]  = 32'h0020928b; 
        
        // 6. ADIFF x6, x3, x4  (dy = |15 - 20| = 5)
        uut.imem_inst.rom[5]  = 32'h0041930b; 
        
        // 7. ADD x7, x5, x6    (h_cost = 6 + 5 = 11)
        uut.imem_inst.rom[6]  = 32'h006283b3; 
        
        // --- FIND MINIMUM COST FOR OPEN LIST ---
        // 8. ADDI x8, x0, 15   (Assume current lowest f_cost in list is 15)
        uut.imem_inst.rom[7]  = 32'h00f00413; 
        
        // 9. UMIN x9, x8, x7   (Compare: Min(15, 11) -> x9 should become 11!)
        uut.imem_inst.rom[8]  = 32'h0074048b; 
        
        // 10. JAL x0, 0        (Infinite Loop to end program)
        uut.imem_inst.rom[9]  = 32'h0000006f; 
        
        // Fill the rest with NOPs
        for(int i=10; i<64; i++) uut.imem_inst.rom[i] = 32'h00000033;
        
        $display("UVM TB: A* Custom Kernel Firmware loaded successfully.");
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