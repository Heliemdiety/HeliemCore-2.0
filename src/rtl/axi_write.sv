`timescale 1ns / 1ps

module axi4_dmem_biu (
    input  logic clk,
    input  logic rst_n,

    
    // CPU Interface 1: LOADS (Read Port)
    input  logic [31:0] cpu_load_addr,
    input  logic        cpu_load_valid,
    output logic        cpu_load_ready,   
    output logic [31:0] cpu_load_data,
    output logic        cpu_load_valid_out, 

   
    // CPU Interface 2: STORES (Write Port)
    input  logic [31:0] cpu_store_addr,
    input  logic [31:0] cpu_store_data,
    input  logic [3:0]  cpu_store_strb,   
    input  logic        cpu_store_valid,
    output logic        cpu_store_ready,  
    output logic        cpu_trap_exception, 

    
    // AXI4-Full Master Interface
    
    // 1. Write Address Channel (AW) 
    output logic [31:0] m_axi_awaddr,
    output logic [7:0]  m_axi_awlen,
    output logic [2:0]  m_axi_awsize,
    output logic [1:0]  m_axi_awburst,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,

    // 2. Write Data Channel (W) 
    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,
    output logic        m_axi_wlast,
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,

    // 3. Write Response Channel (B) 
    input  logic [1:0]  m_axi_bresp,
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,

    // 4. Read Address Channel (AR) 
    output logic [31:0] m_axi_araddr,
    output logic [7:0]  m_axi_arlen,
    output logic [2:0]  m_axi_arsize,
    output logic [1:0]  m_axi_arburst,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,

    // 5. Read Data Channel (R) 
    input  logic [31:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp,
    input  logic        m_axi_rlast,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready
);

    
    // SECTION 1: The Store Buffer & Hazard Detection Unit
    // Architect Note: This buffer prevents the CPU from stalling on every write.
    // The hazard logic prevents Read-After-Write (RAW) data corruption.
    
    logic [31:0] store_buf_addr;
    logic [31:0] store_buf_data;
    logic        store_buf_valid; // 1 = Buffer has live data not yet written to memory
    logic        hazard_match;

    // Detect if the CPU is trying to read the exact address we are currently holding
    assign hazard_match = (store_buf_valid) && (cpu_load_addr == store_buf_addr);

    
    // SECTION 2: D-Mem Write FSM (AW, W, B Channels)
    typedef enum logic [1:0] {
        W_IDLE         = 2'b00,
        W_ACTIVE       = 2'b01, 
        W_WAIT_RESP    = 2'b10  
    } write_state_t;

    write_state_t w_state, w_next_state;       

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) w_state <= W_IDLE;
        else        w_state <= w_next_state;
    end

    always_comb begin
        w_next_state = w_state;
        case (w_state)
            W_IDLE: 
                if (cpu_store_valid) w_next_state = W_ACTIVE;
            W_ACTIVE: 
                // Transition only when BOTH independent handshakes complete
                if (!m_axi_awvalid && !m_axi_wvalid) w_next_state = W_WAIT_RESP;
            W_WAIT_RESP: 
                if (m_axi_bvalid && m_axi_bready) w_next_state = W_IDLE;
            default: w_next_state = W_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awvalid      <= 1'b0;
            m_axi_wvalid       <= 1'b0;
            m_axi_bready       <= 1'b0;
            cpu_store_ready    <= 1'b1;
            store_buf_valid    <= 1'b0;
            cpu_trap_exception <= 1'b0;
        end else begin
            // Clear exception flag every cycle unless actively set below
            cpu_trap_exception <= 1'b0; 

            case (w_state)
                W_IDLE: begin
                    m_axi_bready <= 1'b0;
                    if (cpu_store_valid) begin
                        // 1. Latch data into the Store Buffer
                        store_buf_addr  <= cpu_store_addr;           //  m_axi_awaddr <= cpu_store_addr; mei bhi same hi signal aa rha hai ,, store buffer vala specifically hazard ke liye hai
                        store_buf_data  <= cpu_store_data;
                        m_axi_wstrb     <= cpu_store_strb;
                        store_buf_valid <= 1'b1; // Flag data as live/dirty
                        
                        // 2. Drive AXI Write Channels Simultaneously
                        m_axi_awvalid   <= 1'b1;
                        m_axi_awaddr    <= cpu_store_addr;
                        m_axi_wvalid    <= 1'b1;
                        m_axi_wdata     <= cpu_store_data;
                        
                        // 3. Block further CPU stores
                        cpu_store_ready <= 1'b0; 
                    end
                end

                W_ACTIVE: begin
                    // Drop valid flags independently when slaves accept them
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid && m_axi_wready)   m_axi_wvalid  <= 1'b0;
                    
                    if (!m_axi_awvalid && !m_axi_wvalid) m_axi_bready <= 1'b1;
                end

                W_WAIT_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready    <= 1'b0;
                        store_buf_valid <= 1'b0; 
                        cpu_store_ready <= 1'b1; 
                        
                        // Fire trap if memory rejected the write
                        if (m_axi_bresp != 2'b00) cpu_trap_exception <= 1'b1; 
                    end
                end
            endcase
        end
    end

    
    // SECTION 3: D-Mem Read FSM (AR, R Channels)
    typedef enum logic [1:0] {
        R_IDLE         = 2'b00,
        R_SEND_ADDR    = 2'b01,
        R_RECEIVE_DATA = 2'b10
    } read_state_t;

    read_state_t r_state, r_next_state;
    logic [2:0] beat_ptr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) r_state <= R_IDLE;
        else        r_state <= r_next_state;
    end

    always_comb begin
        r_next_state = r_state;
        case (r_state)
            R_IDLE: 
  
                // Only go to memory if CPU wants data AND it's NOT in our store buffer
                if (cpu_load_valid && !hazard_match) r_next_state = R_SEND_ADDR;
            R_SEND_ADDR: 
                if (m_axi_arvalid && m_axi_arready) r_next_state = R_RECEIVE_DATA;
            R_RECEIVE_DATA: 
                if (m_axi_rvalid && m_axi_rready && m_axi_rlast) r_next_state = R_IDLE;
            default: r_next_state = R_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arvalid  <= 1'b0;
            m_axi_rready   <= 1'b0;
            cpu_load_ready <= 1'b1;
            beat_ptr       <= 3'b000;
        end else begin
            case (r_state)
                R_IDLE: begin
                    m_axi_rready <= 1'b0;
                    beat_ptr     <= 3'b000;
                    if (cpu_load_valid && !hazard_match) begin
                        m_axi_arvalid  <= 1'b1;
                        m_axi_araddr   <= cpu_load_addr;
                        cpu_load_ready <= 1'b0; // Block CPU while fetching
                    end
                end

                R_SEND_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                    end
                end

                R_RECEIVE_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        if (m_axi_rlast) begin
                            m_axi_rready   <= 1'b0;
                            cpu_load_ready <= 1'b1;
                            beat_ptr       <= 3'b000;
                        end else begin
                            beat_ptr <= beat_ptr + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

  
    // SECTION 4: Store-to-Load Forwarding Multiplexers
    // we are handling the RAW (read after write hazard , but instead of stalling we are using data forwarding)
    // The Data Bypass MUX
    // If hazard: Feed the CPU from the Store Buffer.
    // If safe: Feed the CPU from the AXI bus (assuming it's Beat 1 for Early Restart).
    assign cpu_load_data = hazard_match ? store_buf_data : m_axi_rdata;

    // The Valid Bypass MUX
    // If hazard: Tell the CPU the data is ready instantly (0 cycle delay).
    // If safe: Wake up the CPU only on the first beat of the AXI Read Burst.
    assign cpu_load_valid_out = hazard_match ? 1'b1 : 
                                ((r_state == R_RECEIVE_DATA) && m_axi_rvalid && (beat_ptr == 3'b000));

    
    // SECTION 5: Static AXI Assignments
    // Write configurations (Single 32-bit word stores)
    assign m_axi_awlen   = 8'h00;  // 1 beat total (0 + 1)
    assign m_axi_awsize  = 3'b010; // 4 bytes per beat
    assign m_axi_awburst = 2'b01;  // INCR (Doesn't matter for 1 beat)
    assign m_axi_wlast   = 1'b1;   // Since AWLEN is 0, every write beat is the LAST beat

    // Read configurations (Full 256-bit cache line fills)
    assign m_axi_arlen   = 8'h07;  // 8 beats total
    assign m_axi_arsize  = 3'b010; // 4 bytes per beat
    assign m_axi_arburst = 2'b10;  // WRAP burst (Critical word first)

endmodule
