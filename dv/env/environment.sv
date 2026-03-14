import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_env extends uvm_env;
    `uvm_component_utils(cpu_env)

    // Instantiate the components
    cpu_monitor    monitor;
    cpu_scoreboard scoreboard;

    function new(string name = "cpu_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // BUILD PHASE: Create the objects using the UVM Factory
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor    = cpu_monitor::type_id::create("monitor", this);
        scoreboard = cpu_scoreboard::type_id::create("scoreboard", this);
    endfunction

    // CONNECT PHASE: Wire their mailboxes together
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // "Hey Monitor, send your data to the Scoreboard's port"
        monitor.monitor_port.connect(scoreboard.scoreboard_port);
    endfunction

endclass