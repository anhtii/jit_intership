`timescale 1ns/1ps

module top (
    input  wire        clock,      // 100 MHz
    input  wire        reset_n,    // active low (nh?t quán)
    input  wire        rx,         // RXD from USB-UART
    input  wire [7:0]  sw,         // SW[7:0] = data + trigger
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
        .i_Clocks_per_Bit(7'd100), // 1 Mbaud @ 100MHz
        .i_Rx_Serial(rx),
        .o_Rx_DV(rx_dv),
        .o_Rx_Byte(rx_byte)
    );

    // ======================================================
    // UART TX (FPGA -> PC, dùng SW)
    // ======================================================
    wire tx_active;
    wire tx_done;
    
    // Debounce và edge detection cho nút nh?n/sw[0]
    reg [2:0] sw0_sync;
    reg sw0_debounced;
    reg [20:0] debounce_cnt;
    
    // Synchronizer
    always @(posedge clock or posedge reset_n) begin
        if (reset_n)
            sw0_sync <= 3'b000;
        else
            sw0_sync <= {sw0_sync[1:0], sw[0]};
    end
    
    // Simple debounce (20ms @ 100MHz = 2,000,000 cycles)
    always @(posedge clock or posedge reset_n) begin
        if (reset_n) begin
            sw0_debounced <= 1'b0;
            debounce_cnt <= 21'd0;
        end else begin
            if (sw0_sync[2] != sw0_debounced) begin
                if (debounce_cnt == 21'd2_000_000) begin
                    sw0_debounced <= sw0_sync[2];
                    debounce_cnt <= 20'd0;
                end else begin
                    debounce_cnt <= debounce_cnt + 1;
                end
            end else begin
                debounce_cnt <= 20'd0;
            end
        end
    end
    
    // Edge detection
    reg sw0_prev;
    always @(posedge clock or posedge reset_n) begin
        if (reset_n)
            sw0_prev <= 1'b0;
        else
            sw0_prev <= sw0_debounced;
    end
    
    wire tx_dv = sw0_debounced & ~sw0_prev;  // rising edge

    uart_txd uart_tx_inst (
        .i_Clock(clock),
        .i_Reset(reset_n),
        .i_Clocks_per_Bit(7'd100),
        .i_Tx_DV(tx_dv),
        .i_Tx_Byte(sw),          // g?i nguyên 8 bit SW
        .o_Tx_Serial(tx),
        .o_Tx_Active(tx_active),
        .o_Tx_Done(tx_done)
    );

    // ======================================================
    // Debug LED: hi?n th? d? li?u RX t? PC
    // ======================================================
    always @(posedge clock or posedge reset_n) begin
        if (reset_n)
            debug_led <= 8'b0;
        else if (rx_dv)
            debug_led <= rx_byte;
    end

endmodule