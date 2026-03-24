import rv32_pkg::*;

// =============================================================================
// MOCK AXI4 SLAVE MEMORY (Behaves like DDR RAM on a motherboard)
// =============================================================================
module mock_axi_ram #(
    parameter int MEM_SIZE = 1024
) (
    input logic clk,
    input logic rst_n,

    // AR Channel (Read Address)
    input  logic [31:0] araddr,
    input  logic [7:0]  arlen,
    input  logic [2:0]  arsize,
    input  logic [1:0]  arburst,
    input  logic        arvalid,
    output logic        arready,

    // R Channel (Read Data)
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rlast,
    output logic        rvalid,
    input  logic        rready,

    // AW Channel (Write Address)
    input  logic [31:0] awaddr,
    input  logic [7:0]  awlen,
    input  logic [2:0]  awsize,
    input  logic [1:0]  awburst,
    input  logic        awvalid,
    output logic        awready,

    // W Channel (Write Data)
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wlast,
    input  logic        wvalid,
    output logic        wready,

    // B Channel (Write Response)
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready
);

    // The physical memory array
    logic [31:0] ram [0:MEM_SIZE-1];

    initial begin
        for(int i=0; i<MEM_SIZE; i++) ram[i] = 32'h00000033; // Default to NOPs
    end

    // --- AXI Read FSM ---
    typedef enum logic [1:0] { R_IDLE, R_SEND_DATA } r_state_t;
    r_state_t r_state = R_IDLE;
    logic [31:0] read_addr;
    logic [7:0]  read_len;
    logic [7:0]  read_count;

    assign rdata = ram[read_addr[31:2]];
    assign rlast = (r_state == R_SEND_DATA) && (read_count == read_len);
    assign rresp = 2'b00; // OKAY response

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arready <= 1'b1;
            rvalid  <= 1'b0;
            r_state <= R_IDLE;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (arvalid && arready) begin
                        arready    <= 1'b0;
                        read_addr  <= araddr;
                        read_len   <= arlen;
                        read_count <= 8'd0;
                        rvalid     <= 1'b1;
                        r_state    <= R_SEND_DATA;
                    end
                end
                R_SEND_DATA: begin
                    if (rvalid && rready) begin
                        if (read_count == read_len) begin
                            rvalid  <= 1'b0;
                            arready <= 1'b1;
                            r_state <= R_IDLE;
                        end else begin
                            read_count <= read_count + 1'b1;
                            read_addr  <= read_addr + 4; // Advance to next word
                        end
                    end
                end
            endcase
        end
    end

    // --- AXI Write FSM ---
    typedef enum logic [1:0] { W_IDLE, W_WAIT_DATA, W_SEND_RESP } w_state_t;
    w_state_t w_state = W_IDLE;
    logic [31:0] write_addr;

    assign bresp = 2'b00; // OKAY response

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 1'b1;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
            w_state <= W_IDLE;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (awvalid && awready) begin
                        awready    <= 1'b0;
                        wready     <= 1'b1;
                        write_addr <= awaddr;
                        w_state    <= W_WAIT_DATA;
                    end
                end
                W_WAIT_DATA: begin
                    if (wvalid && wready) begin
                        // Byte-level writing based on strobe
                        if (wstrb[0]) ram[write_addr[31:2]][7:0]   <= wdata[7:0];
                        if (wstrb[1]) ram[write_addr[31:2]][15:8]  <= wdata[15:8];
                        if (wstrb[2]) ram[write_addr[31:2]][23:16] <= wdata[23:16];
                        if (wstrb[3]) ram[write_addr[31:2]][31:24] <= wdata[31:24];
                        
                        wready <= 1'b0;
                        if (wlast) begin
                            bvalid  <= 1'b1;
                            w_state <= W_SEND_RESP;
                        end
                    end
                end
                W_SEND_RESP: begin
                    if (bvalid && bready) begin
                        bvalid  <= 1'b0;
                        awready <= 1'b1;
                        w_state <= W_IDLE;
                    end
                end
            endcase
        end
    end
endmodule

// =============================================================================
// MAIN TESTBENCH
// =============================================================================
module tb_axi_soc();

    logic clk;
    logic rst_n;

    // AXI Instruction Bus Wires
    logic [31:0] m_axi_if_araddr;  logic [7:0]  m_axi_if_arlen;
    logic [2:0]  m_axi_if_arsize;  logic [1:0]  m_axi_if_arburst;
    logic        m_axi_if_arvalid; logic        m_axi_if_arready;
    logic [31:0] m_axi_if_rdata;   logic [1:0]  m_axi_if_rresp;
    logic        m_axi_if_rlast;   logic        m_axi_if_rvalid;
    logic        m_axi_if_rready;

    // AXI Data Bus Wires
    logic [31:0] m_axi_mem_awaddr; logic [7:0]  m_axi_mem_awlen;
    logic [2:0]  m_axi_mem_awsize; logic [1:0]  m_axi_mem_awburst;
    logic        m_axi_mem_awvalid;logic        m_axi_mem_awready;
    logic [31:0] m_axi_mem_wdata;  logic [3:0]  m_axi_mem_wstrb;
    logic        m_axi_mem_wlast;  logic        m_axi_mem_wvalid;
    logic        m_axi_mem_wready; logic [1:0]  m_axi_mem_bresp;
    logic        m_axi_mem_bvalid; logic        m_axi_mem_bready;
    logic [31:0] m_axi_mem_araddr; logic [7:0]  m_axi_mem_arlen;
    logic [2:0]  m_axi_mem_arsize; logic [1:0]  m_axi_mem_arburst;
    logic        m_axi_mem_arvalid;logic        m_axi_mem_arready;
    logic [31:0] m_axi_mem_rdata;  logic [1:0]  m_axi_mem_rresp;
    logic        m_axi_mem_rlast;  logic        m_axi_mem_rvalid;
    logic        m_axi_mem_rready;

    // Instantiate CPU Top Module
    riscv_core_top uut (
        .clk(clk), .rst_n(rst_n),
        .* // Auto-connects all the AXI wires named identically above
    );

    // Instantiate Instruction RAM (Connected to IF Bus)
    mock_axi_ram #(.MEM_SIZE(1024)) imem_sys (
        .clk(clk), .rst_n(rst_n),
        .araddr(m_axi_if_araddr), .arlen(m_axi_if_arlen), .arsize(m_axi_if_arsize),
        .arburst(m_axi_if_arburst), .arvalid(m_axi_if_arvalid), .arready(m_axi_if_arready),
        .rdata(m_axi_if_rdata), .rresp(m_axi_if_rresp), .rlast(m_axi_if_rlast),
        .rvalid(m_axi_if_rvalid), .rready(m_axi_if_rready),
        .awaddr(32'h0), .awlen(8'h0), .awsize(3'h0), .awburst(2'h0), .awvalid(1'b0), .awready(),
        .wdata(32'h0), .wstrb(4'h0), .wlast(1'b0), .wvalid(1'b0), .wready(),
        .bresp(), .bvalid(), .bready(1'b0)
    );

    // Instantiate Data RAM (Connected to MEM Bus)
    mock_axi_ram #(.MEM_SIZE(1024)) dmem_sys (
        .clk(clk), .rst_n(rst_n),
        .araddr(m_axi_mem_araddr), .arlen(m_axi_mem_arlen), .arsize(m_axi_mem_arsize),
        .arburst(m_axi_mem_arburst), .arvalid(m_axi_mem_arvalid), .arready(m_axi_mem_arready),
        .rdata(m_axi_mem_rdata), .rresp(m_axi_mem_rresp), .rlast(m_axi_mem_rlast),
        .rvalid(m_axi_mem_rvalid), .rready(m_axi_mem_rready),
        .awaddr(m_axi_mem_awaddr), .awlen(m_axi_mem_awlen), .awsize(m_axi_mem_awsize),
        .awburst(m_axi_mem_awburst), .awvalid(m_axi_mem_awvalid), .awready(m_axi_mem_awready),
        .wdata(m_axi_mem_wdata), .wstrb(m_axi_mem_wstrb), .wlast(m_axi_mem_wlast),
        .wvalid(m_axi_mem_wvalid), .wready(m_axi_mem_wready),
        .bresp(m_axi_mem_bresp), .bvalid(m_axi_mem_bvalid), .bready(m_axi_mem_bready)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=========================================================");
        $display("   RISC-V AXI SoC - FIBONACCI + MEMORY WRITE TEST        ");
        $display("=========================================================");

        clk = 0; rst_n = 0;

        // -------------------------------------------------------------
        // LOAD FIRMWARE INTO THE AXI MOCK RAM (Instead of internal CPU)
        // -------------------------------------------------------------
        imem_sys.ram[0]  = 32'h00000093; // ADDI x1, x0, 0
        imem_sys.ram[1]  = 32'h00100113; // ADDI x2, x0, 1
        imem_sys.ram[2]  = 32'h00c00193; // ADDI x3, x0, 12 (Count)
        imem_sys.ram[3]  = 32'h00000213; // ADDI x4, x0, 0  (Index i)
        imem_sys.ram[4]  = 32'h00320c63; // BEQ x4, x3, 24  (Exit Loop -> jumps to inst 10)
        imem_sys.ram[5]  = 32'h002082b3; // ADD x5, x1, x2  (next = a+b)
        imem_sys.ram[6]  = 32'h002000b3; // ADD x1, x0, x2  (a = b)
        imem_sys.ram[7]  = 32'h00500133; // ADD x2, x0, x5  (b = next)
        imem_sys.ram[8]  = 32'h00120213; // ADDI x4, x4, 1  (i++)
        imem_sys.ram[9]  = 32'hfedff06f; // JAL x0, -20     (Loop back)
        
        // NEW AXI STORE TEST: Write the final answer (x5) to memory address 0x0
        imem_sys.ram[10] = 32'h00502023; // SW x5, 0(x0)
        imem_sys.ram[11] = 32'h0000006f; // JAL x0, 0 (Infinite Loop)

        #20 rst_n = 1; 

        // Because AXI takes multiple clock cycles per instruction (Wait States), 
        // we need to give it more time to run 12 iterations.
        repeat(1500) @(posedge clk); 

        $display("\n--- Verification Results ---");
        $display("Register x5 Final Value : %0d (Expected: 233)", uut.rf_inst.registers[5]);
        $display("Data Memory [0x0] Value : %0d (Expected: 233)", dmem_sys.ram[0]);
        
        if (uut.rf_inst.registers[5] == 32'd233 && dmem_sys.ram[0] == 32'd233) begin
            $display("\nRESULT: SUCCESS! AXI HANDSHAKES AND STALLS WORK PERFECTLY!");
        end else begin
            $display("\nRESULT: FAILED.");
        end

        $finish;
    end
endmodule
