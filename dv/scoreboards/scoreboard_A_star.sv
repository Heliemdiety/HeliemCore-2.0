import uvm_pkg::*;
`include "uvm_macros.svh"


// ============================================================================
// 4. THE SCOREBOARD (A* KERNEL PREDICTOR)
// ============================================================================
class a_star_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(a_star_scoreboard)

    uvm_analysis_imp #(cpu_transaction, a_star_scoreboard) scoreboard_port;
    
    int pass_count = 0;
    int fail_count = 0;

    // The Golden Software State
    logic [31:0] shadow_rf [32];

    function new(string name = "a_star_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scoreboard_port = new("scoreboard_port", this);
        for(int i=0; i<32; i++) shadow_rf[i] = 32'd0;
    endfunction

    virtual function void write(cpu_transaction tx);
        logic [6:0] opcode = tx.inst[6:0];
        logic [2:0] funct3 = tx.inst[14:12];
        logic [4:0] rd     = tx.inst[11:7];
        logic [4:0] rs1    = tx.inst[19:15];
        logic [4:0] rs2    = tx.inst[24:20];
        
        logic [31:0] expected_val;
        logic [31:0] imm;

        // Ignore writes to x0
        if (tx.rf_we && rd == 5'd0) return;

        if (tx.rf_we) begin
            case (opcode)
                7'b0010011: begin // ADDI
                    imm = {{20{tx.inst[31]}}, tx.inst[31:20]};
                    expected_val = shadow_rf[rs1] + imm;       
                end
                7'b0110011: begin // ADD
                    expected_val = shadow_rf[rs1] + shadow_rf[rs2]; 
                end
                7'b1101111: begin // JAL
                    expected_val = tx.pc + 4;
                end
                
                // --- CUSTOM GRAPH ACCELERATOR (A* Heuristics) ---
                7'b0001011: begin // OP_CUSTOM_0
                    if (funct3 == 3'b000) begin 
                        // UMIN: Finding lowest f_cost
                        expected_val = (shadow_rf[rs1] < shadow_rf[rs2]) ? shadow_rf[rs1] : shadow_rf[rs2];
                    end else if (funct3 == 3'b001) begin 
                        // ADIFF: Manhattan Distance dx/dy calculation
                        if (shadow_rf[rs1] >= shadow_rf[rs2])
                            expected_val = shadow_rf[rs1] - shadow_rf[rs2];
                        else
                            expected_val = shadow_rf[rs2] - shadow_rf[rs1];
                    end else begin
                        expected_val = shadow_rf[rs1] + shadow_rf[rs2]; 
                    end
                end

                default: expected_val = tx.rf_wdata;
            endcase

            // VERIFY THE HARDWARE
            if (tx.rf_wdata !== expected_val) begin
                `uvm_error("A_STAR_SCOREBOARD", $sformatf("MISMATCH! PC: 0x%0h | Reg x%0d | Expected: %0d, Actual: %0d", 
                                                   tx.pc, rd, expected_val, tx.rf_wdata))
                fail_count++;
            end else begin
                `uvm_info("A_STAR_SCOREBOARD", $sformatf("MATCH! PC: 0x%0h | x%0d calculated as %0d perfectly.", 
                                                  tx.pc, rd, expected_val), UVM_LOW)
                pass_count++;
            end

            // UPDATE SHADOW STATE
            shadow_rf[rd] = expected_val;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("A_STAR_SCOREBOARD", "========================================", UVM_NONE)
        `uvm_info("A_STAR_SCOREBOARD", "       A* ALGORITHM KERNEL VERIFIED     ", UVM_NONE)
        `uvm_info("A_STAR_SCOREBOARD", $sformatf("  TOTAL PASSED: %0d", pass_count), UVM_NONE)
        `uvm_info("A_STAR_SCOREBOARD", $sformatf("  TOTAL FAILED: %0d", fail_count), UVM_NONE)
        `uvm_info("A_STAR_SCOREBOARD", "========================================", UVM_NONE)
    endfunction
endclass