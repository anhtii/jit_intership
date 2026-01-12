`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/10/2026 09:07:30 PM
// Design Name: 
// Module Name: uart_txd
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
// UART Transmitter (8N1)
// - 1 start bit (0)
// - 8 data bits (LSB first)
// - 1 stop bit (1)
// ============================================================

module uart_txd (
    input  wire        i_Clock,
    input  wire        i_Reset,
    input  wire [6:0] i_Clocks_per_Bit, // clk / baud
    input  wire        i_Tx_DV,           // Bit bat dau truyen
    input  wire [7:0]  i_Tx_Byte,         // Du lieu muon gui

    output reg         o_Tx_Serial,        // du lieu TXD
    output wire        o_Tx_Active,        // Bao dang truyen
    output wire        o_Tx_Done            // Xong
);

    // ========================================================
    // FSM state encoding
    // ========================================================
    localparam TX_IDLE  = 3'd0;
    localparam TX_START = 3'd1;
    localparam TX_DATA  = 3'd2;
    localparam TX_STOP  = 3'd3;
    localparam TX_DONE  = 3'd4;

    reg [2:0] tx_state;

    // ========================================================
    // Internal registers
    // ========================================================
    reg [6:0] baud_cnt;        // Dem so xung fpga de hoan thanh truyen 1 bit
    reg [2:0]  bit_idx;         // 0..7
    reg [7:0]  tx_shift_reg;    // thanh ghi luu du lieu data
    reg        tx_busy;
    reg        tx_done;

    // ========================================================
    // FSM
    // ========================================================
    always @(posedge i_Clock or posedge i_Reset) begin
        if (i_Reset) begin
            tx_state      <= TX_IDLE;
            o_Tx_Serial   <= 1'b1;   // idle = high
            baud_cnt      <= 0;
            bit_idx       <= 0;
            tx_shift_reg  <= 0;
            tx_busy       <= 1'b0;
            tx_done       <= 1'b0;
        end else begin
            tx_done <= 1'b0; // default

            case (tx_state)

                // ------------------------------------------------
                // IDLE: wait for transmit request
                // ------------------------------------------------
                TX_IDLE: begin
                    o_Tx_Serial <= 1'b1;
                    baud_cnt    <= 0;
                    bit_idx     <= 0;
                    tx_busy     <= 1'b0;

                    if (i_Tx_DV) begin
                        tx_shift_reg <= i_Tx_Byte; // latch data
                        tx_busy      <= 1'b1;
                        tx_state     <= TX_START;
                    end
                end

                // ------------------------------------------------
                // START BIT (0)
                // ------------------------------------------------
                TX_START: begin
                    o_Tx_Serial <= 1'b0;

                    if (baud_cnt < i_Clocks_per_Bit - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        tx_state <= TX_DATA;
                    end
                end

                // ------------------------------------------------
                // DATA BITS (LSB first)
                // ------------------------------------------------
                TX_DATA: begin
                    o_Tx_Serial <= tx_shift_reg[bit_idx];

                    if (baud_cnt < i_Clocks_per_Bit - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        if (bit_idx < 7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            bit_idx <= 0;
                            tx_state <= TX_STOP;
                        end
                    end
                end

                // ------------------------------------------------
                // STOP BIT (1)
                // ------------------------------------------------
                TX_STOP: begin
                    o_Tx_Serial <= 1'b1;

                    if (baud_cnt < i_Clocks_per_Bit - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        tx_done  <= 1'b1;
                        tx_busy  <= 1'b0;
                        tx_state <= TX_DONE;
                    end
                end

                // ------------------------------------------------
                // DONE (1 clock)
                // ------------------------------------------------
                TX_DONE: begin
                    tx_done  <= 1'b1;
                    tx_state <= TX_IDLE;
                end

                default:
                    tx_state <= TX_IDLE;

            endcase
        end
    end

    assign o_Tx_Active = tx_busy;
    assign o_Tx_Done   = tx_done;

endmodule

