`timescale 1ns/1ps

module top (
    input  wire        clock,      // 100 MHz
    input  wire        reset_n,    // active HIGH reset
    input  wire        rx,         // RXD from USB-UART
    input  wire [7:0]  sw,         // SW[7:0] = data
    output wire        tx,         // TXD to USB-UART
    output reg  [7:0]  debug_led,  // show received byte
    output wire        heartbeat
);

    // ======================================================
    // Heartbeat
    // ======================================================
    reg [27:0] hb_cnt;
    always @(posedge clock or posedge reset_n) begin
        if (reset_n)
            hb_cnt <= 28'd0;
        else
            hb_cnt <= hb_cnt + 1;
    end
    assign heartbeat = hb_cnt[27];

    // ======================================================
    // UART RX (PC -> FPGA)
    // ======================================================
    wire       rx_dv;
    wire [7:0] rx_byte;

    uart_rxd uart_rx_inst (
        .i_Clock(clock),
        .i_Reset(reset_n),
        .i_Clocks_per_Bit(7'd100), // 1 Mbaud @ 100 MHz
        .i_Rx_Serial(rx),
        .o_Rx_DV(rx_dv),
        .o_Rx_Byte(rx_byte)
    );

    // RX data -> LED
    always @(posedge clock or posedge reset_n) begin
        if (reset_n)
            debug_led <= 8'b0;
        else if (rx_dv)
            debug_led <= rx_byte;
    end

    // ======================================================
    // AUTO SEND: FPGA -> PC when SW changes
    // ======================================================
    reg [7:0] sw_prev;

    always @(posedge clock or posedge reset_n) begin
        if (reset_n)
            sw_prev <= 8'b0;
        else
            sw_prev <= sw;
    end

    // detect change
    wire tx_dv = (sw != sw_prev);

    // ======================================================
    // UART TX
    // ======================================================
    uart_txd uart_tx_inst (
        .i_Clock(clock),
        .i_Reset(reset_n),
        .i_Clocks_per_Bit(7'd100),
        .i_Tx_DV(tx_dv),
        .i_Tx_Byte(sw),
        .o_Tx_Serial(tx),
        .o_Tx_Active(),
        .o_Tx_Done()
    );

endmodule
