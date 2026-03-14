import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_monitor)

    // The virtual interface: A pointer to the physical wires
    virtual cpu_if vif;

    // The Mailbox: How the Monitor sends the object to the Scoreboard
    uvm_analysis_port #(cpu_transaction) monitor_port;

    // Constructor
    function new(string name = "cpu_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase: UVM uses this to connect things before time 0
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor_port = new("monitor_port", this);
        
        // This is UVM magic: Grab the interface from the configuration database The Senior Architect's Question to You:
// Notice line 24 in the cpu_monitor.sv. It uses something called the uvm_config_db.
// In standard Verilog, we connect modules using physical wires in a Top Module (.clk(clk)). But classes in SystemVerilog (like our Monitor) don't have physical pins! So how does the software Monitor actually connect to the hardware Interface wires? It uses the UVM Configuration Database—a global dictionary where the Top Module "deposits" the interface pointer, and the Monitor "retrieves" it.
// Take a look through the run_phase in the Monitor and the write function in the Scoreboard.
        if (!uvm_config_db#(virtual cpu_if)::get(this, "", "vif", vif)) begin                           
            `uvm_fatal("MON_ERR", "Failed to get virtual interface from config DB!")
        end
    endfunction

    // Run Phase: This is the actual hardware simulation loop!
    virtual task run_phase(uvm_phase phase);
        cpu_transaction tx;
        
        forever begin
            // Wait for a clock edge using our clocking block
            @(vif.monitor_cb);

            // Wait until an instruction actually writes to the Register File
            if (vif.monitor_cb.rf_we == 1'b1) begin
                // Create a brand new transaction object
                tx = cpu_transaction::type_id::create("tx");
                
                // Pack the hardware signals into the software object
                tx.pc       = vif.monitor_cb.pc;
                tx.inst     = vif.monitor_cb.inst;
                tx.rf_we    = vif.monitor_cb.rf_we;
                tx.rf_waddr = vif.monitor_cb.rf_waddr;
                tx.rf_wdata = vif.monitor_cb.rf_wdata;

                // Print what we saw (for debugging)
                `uvm_info("MONITOR", $sformatf("Observed: %s", tx.convert2string()), UVM_HIGH)

                // Broadcast the transaction to the Scoreboard!
                monitor_port.write(tx);
            end
        end
    endtask
endclass