import rv32_pkg::*;

module rv32_memory (
    input  logic    clk,
    input  logic    rst_n,
    input  logic    global_stall, // Global AXI Freeze

    // Inputs from EX/MEM Pipeline Register
    input  ex_mem_t ex_mem_reg,
    input  word_t   ex_mem_pc_plus_4,

    // AXI DMEM BIU Handshake
    output logic [31:0] cpu_load_addr,
    output logic        cpu_load_valid,
    input  logic        cpu_load_ready,
    input  logic [31:0] cpu_load_data,
    input  logic        cpu_load_valid_out,

    output logic [31:0] cpu_store_addr,
    output logic [31:0] cpu_store_data,
    output logic [3:0]  cpu_store_strb,
    output logic        cpu_store_valid,
    input  logic        cpu_store_ready,
    input  logic        cpu_trap_exception,

    // Output to Hazard Unit
    output logic        mem_bus_stall,

    // Output to MEM/WB Pipeline Register
    output mem_wb_t     mem_wb_data
);

    logic [1:0] addr_align;
    assign addr_align = ex_mem_reg.alu_result[1:0];

    // AXI Handshake Mapping 
    // Word align the addresses for the BIU
    assign cpu_load_addr   = {ex_mem_reg.alu_result[31:2], 2'b00};
    assign cpu_load_valid  = ex_mem_reg.ctrl.mem_read;
    
    assign cpu_store_addr  = {ex_mem_reg.alu_result[31:2], 2'b00};
    assign cpu_store_valid = ex_mem_reg.ctrl.mem_write;

    
    // 1. Store Data Alignment & Strobes
    always_comb begin
        cpu_store_data = ex_mem_reg.rs2_data;
        cpu_store_strb = 4'b0000;

        if (ex_mem_reg.ctrl.mem_write) begin
            case (ex_mem_reg.ctrl.mem_size)
                3'b000: begin
                    cpu_store_data = {4{ex_mem_reg.rs2_data[7:0]}};
                    cpu_store_strb = 4'b0001 << addr_align;
                end
                3'b001: begin
                    cpu_store_data = {2{ex_mem_reg.rs2_data[15:0]}};
                    cpu_store_strb = 4'b0011 << addr_align;
                end
                3'b010: cpu_store_strb = 4'b1111;
                default: cpu_store_strb = 4'b0000;
            endcase
        end
    end


    // 2. The "Catcher Mitt" for Loads
    logic [31:0] latched_rdata;
    logic        latched_rvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_rvalid <= 1'b0;
        end else begin
            // Catch data if AXI finishes but the IF stage is freezing the pipeline
            if (cpu_load_valid_out && global_stall) begin
                latched_rdata  <= cpu_load_data;
                latched_rvalid <= 1'b1;
            end else if (!global_stall) begin
                latched_rvalid <= 1'b0;
            end
        end
    end

    word_t raw_rdata;
    assign raw_rdata = latched_rvalid ? latched_rdata : cpu_load_data;

    // Bus Stall Logic
    // Stall the CPU if we are waiting for a load to return, OR if the store buffer is full
    assign mem_bus_stall = (ex_mem_reg.ctrl.mem_read && !(cpu_load_valid_out || latched_rvalid)) ||
                           (ex_mem_reg.ctrl.mem_write && !cpu_store_ready);

    
    // 3. Load Data Extraction & Extension
    word_t       formatted_rdata;
    logic [7:0]  byte_read;
    logic [15:0] half_read;

    always_comb begin
        case (addr_align)
            2'b00: byte_read = raw_rdata[7:0];
            2'b01: byte_read = raw_rdata[15:8];
            2'b10: byte_read = raw_rdata[23:16];
            2'b11: byte_read = raw_rdata[31:24];
        endcase

        case (addr_align[1])
            1'b0: half_read = raw_rdata[15:0];
            1'b1: half_read = raw_rdata[31:16];
        endcase

        case (ex_mem_reg.ctrl.mem_size)
            3'b000: formatted_rdata = { {24{byte_read[7]}}, byte_read };      // LB
            3'b001: formatted_rdata = { {16{half_read[15]}}, half_read };     // LH
            3'b010: formatted_rdata = raw_rdata;                              // LW
            3'b100: formatted_rdata = { 24'b0, byte_read };                   // LBU
            3'b101: formatted_rdata = { 16'b0, half_read };                   // LHU
            default: formatted_rdata = raw_rdata;
        endcase
    end

   
    // 4. Package for WB
    always_comb begin
        mem_wb_data.alu_result    = ex_mem_reg.alu_result;
        mem_wb_data.mem_read_data = formatted_rdata;
        mem_wb_data.pc_plus_4     = ex_mem_pc_plus_4;
        mem_wb_data.rd            = ex_mem_reg.rd;
        mem_wb_data.ctrl          = ex_mem_reg.ctrl;
    end

endmodule
