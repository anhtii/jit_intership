`timescale 1ns / 1ps

module top (
    input  wire        clock,      // 100 MHz
    input  wire        reset_n,    // active HIGH
    input  wire        rx,         // UART RX
    input  wire [10:0] sw,         // sw[10:8] mode, sw[7:0] data
    output wire        tx,         // UART TX
    output reg  [7:0]  debug_led,  // LED ??n
    output wire        heartbeat,

    // I2C ADT7420
    inout  wire        sda,
    output wire        scl,
    output [6:0] seg,
    output [7:0] an
);

    // =====================================================
    // Reset
    // =====================================================
    wire rst = reset_n;

    // =====================================================
    // Heartbeat
    // =====================================================
    reg [27:0] hb_cnt;
    always @(posedge clock or posedge rst) begin
        if (rst)
            hb_cnt <= 28'd0;
        else
            hb_cnt <= hb_cnt + 1;
    end
    assign heartbeat = hb_cnt[27];

    // =====================================================
    // Debounce SW[7:0]
    // =====================================================
    wire [7:0] debouncedd;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : DEB
            debounced debounce_inst (
                .clk   (clock),
                .reset (rst),
                .sw_in (sw[i]),
                .sw_out(debouncedd[i])
            );
        end
    endgenerate

    // =====================================================
    // I2C ADT7420
    // =====================================================
    wire [7:0] rd_data;

    i2c_adt7420_controller u_i2c (
        .sys_clk (clock),
        .sys_rst (rst),
        .i2c_sda (sda),
        .i2c_scl (scl),
        .rd_data (rd_data),
        .seg     (seg),     
        .an      (an)
    );

    // =====================================================
    // UART RX (PC -> FPGA)
    // =====================================================
    wire       rx_dv;
    wire [7:0] rx_byte;

    uart_rxd uart_rx_inst (
        .i_Clock(clock),
        .i_Reset(rst),
        .i_Clocks_per_Bit(16'd100), // 115200 baud
        .i_Rx_Serial(rx),
        .o_Rx_DV(rx_dv),
        .o_Rx_Byte(rx_byte)
    );

    // =====================================================
    // LED control (MODE_LED)
    // =====================================================
    always @(posedge clock or posedge rst) begin
        if (rst)
            debug_led <= 8'd0;
        else if (sw[9] && rx_dv)
            debug_led <= rx_byte;
    end

    // =====================================================
    // UART TX
    // =====================================================
    reg        tx_dv;
    reg [7:0]  tx_byte;

    uart_txd uart_tx_inst (
        .i_Clock(clock),
        .i_Reset(rst),
        .i_Clocks_per_Bit(16'd100),
        .i_Tx_DV(tx_dv),
        .i_Tx_Byte(tx_byte),
        .o_Tx_Serial(tx),
        .o_Tx_Active(),
        .o_Tx_Done()
    );

    // =====================================================
    // TX MODE CONTROLLER - FIXED VERSION
    // =====================================================
    reg [7:0] prev_temp;
    reg [7:0] prev_sw;
    
    // Thêm bi?n ?? tránh g?i liên t?c
    reg sw_sent_flag;
    reg temp_sent_flag;

    always @(posedge clock or posedge rst) begin
        if (rst) begin
            tx_dv     <= 1'b0;
            tx_byte   <= 8'd0;
            prev_temp <= 8'd0;
            prev_sw   <= 8'd0;
            sw_sent_flag <= 1'b0;
            temp_sent_flag <= 1'b0;
        end else begin
            tx_dv <= 1'b0;  // M?c ??nh là không g?i
            
            // Reset flags khi chuy?n mode
            if (!sw[10]) sw_sent_flag <= 1'b0;
            if (!sw[8]) temp_sent_flag <= 1'b0;

        // =========================
        // MODE_SW: FPGA -> PC (ch? g?i giá tr? SW)
        // =========================
        if (sw[10]) begin
            // Khi SW thay ??i
            if (debouncedd != prev_sw) begin
                prev_sw <= debouncedd;
                sw_sent_flag <= 1'b0;  // Cho phép g?i
            end
            
            // G?i khi SW thay ??i và ch?a g?i
            if ((debouncedd != prev_sw) && !sw_sent_flag) begin
                tx_byte <= debouncedd;  // G?i giá tr? SW
                tx_dv   <= 1'b1;
                sw_sent_flag <= 1'b1;   // ?ánh d?u ?ã g?i
            end
        end

        // =========================
        // MODE_TEMP: FPGA -> PC (ch? g?i nhi?t ??)
        // =========================
        else if (sw[8]) begin
            // Khi nhi?t ?? thay ??i
            if (rd_data != prev_temp) begin
                prev_temp <= rd_data;
                temp_sent_flag <= 1'b0;  // Cho phép g?i
            end
            
            // G?i khi nhi?t ?? thay ??i và ch?a g?i
            if ((rd_data != prev_temp) && !temp_sent_flag) begin
                tx_byte <= rd_data;  // G?i giá tr? nhi?t ??
                tx_dv   <= 1'b1;
                temp_sent_flag <= 1'b1;  // ?ánh d?u ?ã g?i
            end
        end

        // =========================
        // MODE_LED: PC -> FPGA (không g?i gì c?)
        // =========================
        else if (sw[9]) begin
            // Không làm gì, ch? nh?n d? li?u t? PC
        end
        end
    end

endmodule