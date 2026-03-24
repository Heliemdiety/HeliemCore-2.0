module axi4_ifetch_biu (
    input  logic clk,
    input  logic rst_n,

    // CPU Pipeline Interface
    input  logic [31:0] cpu_req_addr,           
    input  logic        cpu_req_valid,          
    output logic        cpu_req_ready,           
    
    output logic [31:0] cpu_instr_out,          
    output logic        cpu_instr_valid,        
    
    // AXI4-Full Read Address (AR) Channel
    output logic [31:0] m_axi_araddr,           
    output logic [7:0]  m_axi_arlen,            
    output logic [2:0]  m_axi_arsize,           
    output logic [1:0]  m_axi_arburst,          
    output logic        m_axi_arvalid,          
    input  logic        m_axi_arready,          
    
    // AXI4-Full Read Data (R) Channel
    input  logic [31:0] m_axi_rdata,           
    input  logic [1:0]  m_axi_rresp,            
    input  logic        m_axi_rlast,             
    input  logic        m_axi_rvalid,           
    output logic        m_axi_rready           
);

  
    // 1. FSM State Declarations
    typedef enum logic [1:0] {
        IDLE         = 2'b00,
        SEND_ADDR    = 2'b01,
        RECEIVE_DATA = 2'b10
    } state_t;

    state_t current_state, next_state;

  
    // 2. Sequential State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // 3. Combinational Next-State Logic
    always_comb begin
        // Default assignment to prevent latches
        next_state = current_state; 

        case (current_state)
            IDLE: begin
                if (cpu_req_valid) begin
                    next_state = SEND_ADDR;
                end
            end

            SEND_ADDR: begin
                // Transition only when the AXI handshake occurs
                if (m_axi_arvalid && m_axi_arready) begin
                    next_state = RECEIVE_DATA;
                end
            end

            RECEIVE_DATA: begin
                // Stay here until the LAST beat of the burst arrives
                if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end


    // 4. Output Logic (Registered for Timing Closure)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            cpu_req_ready <= 1'b1; // We start ready for the CPU
        end else begin
            
            case (current_state)
                IDLE: begin
                    m_axi_rready <= 1'b0;
                    if (cpu_req_valid) begin
                        m_axi_arvalid <= 1'b1;         
                        m_axi_araddr  <= cpu_req_addr; // Latch CPU address
                        cpu_req_ready <= 1'b0;         // Tell CPU to wait
                    end
                end

                SEND_ADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0; // Handshake done, drop ARVALID
                        m_axi_rready  <= 1'b1; // Immediately prepare to receive data
                    end
                end

                RECEIVE_DATA: begin
                    if (m_axi_rvalid && m_axi_rlast) begin
                        m_axi_rready  <= 1'b0; // Burst done, drop RREADY
                        cpu_req_ready <= 1'b1; // Ready for the next CPU request
                    end
                end
            endcase
        end
    end


    // 3-bit pointer (counts from 0 to 7)
    logic [2:0]  beat_ptr;

    // array (Line Fill Buffer) If we don't have a place to physically store beats 1 through 8 as they arrive, they just overwrite each other on the wire, and 7 of the 8 instructions vanish into thin air.
    //To fix this, we need to declare an internal memory array (a small SRAM or register file) inside our axi4_ifetch_biu module to catch the 8 beats.
    
    
    logic [31:0] line_fill_buffer [7:0];  // (32 x 8 bits to catch 8 instructions in a buffer array)

    // 5. Static AXI Burst Configuration (Hardcoded for Cache Lines)
    assign m_axi_arlen   = 8'h07;  // 8 beats total (for a 256-bit cache line)
    assign m_axi_arsize  = 3'b010; // 4 bytes (32-bits) per beat
    assign m_axi_arburst = 2'b10;  // WRAP burst (Critical word first)
    
    // (if we directly get the instruction we need in the very first beat, we can move with our procedure , without waiting for the next 7 beats to come ,, the instr valid can go high )
    assign cpu_instr_out = m_axi_rdata;
    assign cpu_instr_valid = (current_state == RECEIVE_DATA) && 
                             (m_axi_rvalid) && 
                             (beat_ptr == 3'b000);



    // The Datapath Logic 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beat_ptr <= 3'b000;
        end else if (current_state == RECEIVE_DATA) begin
            if (m_axi_rvalid && m_axi_rready) begin
                
                // 1. Catch the data and put it in the array at the current pointer
                line_fill_buffer[beat_ptr] <= m_axi_rdata;
                
                // 2. Move the pointer to the next slot
                if (m_axi_rlast) begin
                    beat_ptr <= 3'b000; // Reset pointer on the last beat
                end else begin
                    beat_ptr <= beat_ptr + 1'b1; // Increment normally
                end
            end
        end
    end

endmodule
