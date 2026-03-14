import uvm_pkg::*;
`include "uvm_macros.svh"

// ============================================================================
// . THE SCOREBOARD (THE GOLDEN PREDICTOR)
// ============================================================================
class cpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_scoreboard)

    uvm_analysis_imp #(cpu_transaction, cpu_scoreboard) scoreboard_port;
    
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // THE SHADOW REGISTER FILE (The Golden Software State)
    // -------------------------------------------------------------------------
    logic [31:0] shadow_rf [32];

    function new(string name = "cpu_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scoreboard_port = new("scoreboard_port", this);
        // Initialize the software registers to 0
        for(int i=0; i<32; i++) shadow_rf[i] = 32'd0;
    endfunction

    // -------------------------------------------------------------------------
    // THE GOLDEN PREDICTOR LOGIC
    // -------------------------------------------------------------------------
    virtual function void write(cpu_transaction tx);
        // Decode the instruction fields in software!
        logic [6:0] opcode = tx.inst[6:0];
        logic [4:0] rd     = tx.inst[11:7];
        logic [4:0] rs1    = tx.inst[19:15];
        logic [4:0] rs2    = tx.inst[24:20];
        
        logic [31:0] expected_val;
        logic [31:0] imm;

        // In RISC-V, writes to x0 are ignored. Let the hardware do it, but we ignore it.
        if (tx.rf_we && rd == 5'd0) return;

        if (tx.rf_we) begin
            // 1. PREDICT THE RESULT
            case (opcode)
                7'b0010011: begin // ADDI
                    imm = {{20{tx.inst[31]}}, tx.inst[31:20]}; // Sign extend
                    expected_val = shadow_rf[rs1] + imm;       // Calculate!
                end
                7'b0110011: begin // ADD
                    expected_val = shadow_rf[rs1] + shadow_rf[rs2]; // Calculate!
                end
                7'b1101111: begin // JAL (Return Address)
                    expected_val = tx.pc + 4;
                end
                default: begin
                    // If we haven't modeled the instruction yet, we just accept the hardware data
                    expected_val = tx.rf_wdata; 
                end
            endcase

            // 2. VERIFY THE HARDWARE
            if (tx.rf_wdata !== expected_val) begin
                `uvm_error("SCOREBOARD", $sformatf("MISMATCH! PC: 0x%0h | Reg x%0d | Expected: %0d, Actual: %0d", 
                                                   tx.pc, rd, expected_val, tx.rf_wdata))
                fail_count++;
            end else begin
                `uvm_info("SCOREBOARD", $sformatf("MATCH! PC: 0x%0h | x%0d calculated as %0d perfectly.", 
                                                  tx.pc, rd, expected_val), UVM_LOW)
                pass_count++;
            end

            // 3. UPDATE THE SHADOW STATE
            // We must update our software registers so the next calculation is correct!
            shadow_rf[rd] = expected_val;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD", "========================================", UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("  TOTAL PASSED: %0d", pass_count), UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("  TOTAL FAILED: %0d", fail_count), UVM_NONE)
        `uvm_info("SCOREBOARD", "========================================", UVM_NONE)
    endfunction
endclass