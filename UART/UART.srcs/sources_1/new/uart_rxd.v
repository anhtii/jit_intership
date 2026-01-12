`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/11/2026 08:36:53 PM
// Design Name: 
// Module Name: uart_rxd
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


module uart_rxd (
    input  wire        i_Clock,
    input  wire        i_Reset,
    input  wire [6:0]  i_Clocks_per_Bit, // clk / baud (same as TX)
    input  wire        i_Rx_Serial,       // RXD line

    output reg         o_Rx_DV,            // data valid (1 clk)
    output reg [7:0]   o_Rx_Byte           // received byte
);

    // ========================================================
    // FSM states
    // ========================================================
    localparam RX_IDLE  = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA  = 3'd2;
    localparam RX_STOP  = 3'd3;
    localparam RX_DONE  = 3'd4;

    reg [2:0] rx_state;

    // ========================================================
    // Internal registers
    // ========================================================
    reg [6:0] baud_cnt;        // clock counter
    reg [2:0] bit_idx;         // 0..7
    reg [7:0] rx_shift_reg;

    // ========================================================
    // UART RX FSM
    // ========================================================
    always @(posedge i_Clock or posedge i_Reset) begin
        if (i_Reset) begin
            rx_state     <= RX_IDLE;
            baud_cnt     <= 0;
            bit_idx      <= 0;
            rx_shift_reg <= 0;
            o_Rx_Byte    <= 0;
            o_Rx_DV      <= 1'b0;
        end else begin
            o_Rx_DV <= 1'b0; // default

            case (rx_state)

                // --------------------------------------------
                // IDLE: wait for start bit (RXD goes low)
                // --------------------------------------------
                RX_IDLE: begin
                    baud_cnt <= 0;
                    bit_idx  <= 0;

                    if (i_Rx_Serial == 1'b0) begin
                        rx_state <= RX_START;
                    end
                end

                // --------------------------------------------
                // START: wait half bit, sample start bit
                // --------------------------------------------
                RX_START: begin
                    if (baud_cnt < (i_Clocks_per_Bit >> 1)) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        // confirm still low
                        if (i_Rx_Serial == 1'b0)
                            rx_state <= RX_DATA;
                        else
                            rx_state <= RX_IDLE; // false start
                    end
                end

                // --------------------------------------------
                // DATA: sample 8 data bits (LSB first)
                // --------------------------------------------
                RX_DATA: begin
                    if (baud_cnt < i_Clocks_per_Bit - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;

                        // sample in middle of bit
                        rx_shift_reg[bit_idx] <= i_Rx_Serial;

                        if (bit_idx < 7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            bit_idx <= 0;
                            rx_state <= RX_STOP;
                        end
                    end
                end

                // --------------------------------------------
                // STOP bit
                // --------------------------------------------
                RX_STOP: begin
                    if (baud_cnt < i_Clocks_per_Bit - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt  <= 0;
                        o_Rx_Byte <= rx_shift_reg;
                        o_Rx_DV   <= 1'b1;
                        rx_state  <= RX_DONE;
                    end
                end

                // --------------------------------------------
                // DONE (1 clock)
                // --------------------------------------------
                RX_DONE: begin
                    rx_state <= RX_IDLE;
                end

                default:
                    rx_state <= RX_IDLE;

            endcase
        end
    end

endmodule

