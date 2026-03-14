import uvm_pkg::*;
`include "uvm_macros.svh"

class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    cpu_env env;

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cpu_env::type_id::create("env", this);
    endfunction

    // RUN PHASE: The actual simulation timeline
    virtual task run_phase(uvm_phase phase);
        // Tell UVM: "Don't stop the simulation, I am busy!"
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting UVM Test...", UVM_LOW)
        
        // Let the CPU run for 4000 nanoseconds (plenty of time for Fibonacci)
        #4000ns;
        
        `uvm_info("TEST", "Test duration complete.", UVM_LOW)
        
        // Tell UVM: "I am done, you can stop the simulation now."
        phase.drop_objection(this);
    endtask

endclass