`timescale 1ns / 1ps

module temperature_display(
    input  wire        sys_clk,
    input  wire        rst,
    input  wire        temp_done,
    input  wire [15:0] temp_value,   // VD: 25.25°C -> 2525

    output reg  [6:0]  seg,
    output reg  [7:0]  an
);

    // ============================================================
    // 1) Latch nhi?t ?? khi temp_done lên 1 (gi? ?n ??nh khi scan)
    // ============================================================
    reg [15:0] temp_latched;

    always @(posedge sys_clk or posedge rst) begin
        if (rst)
            temp_latched <= 16'd0;
        else if (temp_done)
            temp_latched <= temp_value;
    end

    // ============================================================
    // 2) Tách s? nguyên và ph?n th?p phân t? centi-degree (x100)
    // ============================================================
    wire [15:0] temp_centi = temp_latched;     // 0..65535 => 0.00..655.35°C

    wire [9:0]  temp_int   = temp_centi / 16'd100;  // ph?n nguyên (0..655)
    wire [6:0]  temp_frac  = temp_centi % 16'd100;  // ph?n l? (0..99)

    wire [3:0] int_tens    = (temp_int / 10) % 10;
    wire [3:0] int_ones    = temp_int % 10;

    wire [3:0] frac_tens   = temp_frac / 10;
    wire [3:0] frac_ones   = temp_frac % 10;

    // ============================================================
    // 3) Encode 7-seg (common anode ki?u 0 sáng, 1 t?t)
    // ============================================================
    function [6:0] seg7_encode_digit;
        input [3:0] b;
        begin
            case (b)
                4'd0: seg7_encode_digit = 7'b1000000;
                4'd1: seg7_encode_digit = 7'b1111001;
                4'd2: seg7_encode_digit = 7'b0100100;
                4'd3: seg7_encode_digit = 7'b0110000;
                4'd4: seg7_encode_digit = 7'b0011001;
                4'd5: seg7_encode_digit = 7'b0010010;
                4'd6: seg7_encode_digit = 7'b0000010;
                4'd7: seg7_encode_digit = 7'b1111000;
                4'd8: seg7_encode_digit = 7'b0000000;
                4'd9: seg7_encode_digit = 7'b0010000;
                default: seg7_encode_digit = 7'b1111111;
            endcase
        end
    endfunction

    function [6:0] seg7_encode_C;
        input dummy;
        begin
            seg7_encode_C = 7'b1000110; // C
        end
    endfunction

    function [6:0] seg7_degree;
        input dummy;
        begin
            seg7_degree = 7'b0011100; // ký hi?u ?? (t? ch?nh n?u mu?n)
        end
    endfunction

    // ============================================================
    // 4) Quét LED 7 ?o?n (8 digit, dùng 6 digit)
    // ============================================================
    reg [17:0] scan_cnt;

    always @(posedge sys_clk or posedge rst) begin
        if (rst)
            scan_cnt <= 18'd0;
        else
            scan_cnt <= scan_cnt + 1'b1;
    end

    wire [2:0] digit_sel = scan_cnt[17:15];  // 0..7

    reg [6:0] seg_next;
    reg [7:0] an_next;

    always @(*) begin
        seg_next = 7'b1111111;
        an_next  = 8'b1111_1111;

        case (digit_sel)
            3'd0: begin
                // AN0: C
                seg_next = seg7_encode_C(1'b0);
                an_next  = 8'b1111_1110;
            end

            3'd1: begin
                // AN1: ký hi?u ??
                seg_next = seg7_degree(1'b0);
                an_next  = 8'b1111_1101;
            end

            3'd2: begin
                // AN2: frac ones
                seg_next = seg7_encode_digit(frac_ones);
                an_next  = 8'b1111_1011;
            end

            3'd3: begin
                // AN3: frac tens
                seg_next = seg7_encode_digit(frac_tens);
                an_next  = 8'b1111_0111;
            end

            3'd4: begin
                // AN4: int ones (n?u mu?n d?u ch?m thì ph?i có seg[7] dp riêng)
                seg_next = seg7_encode_digit(int_ones);
                an_next  = 8'b1110_1111;
            end

            3'd5: begin
                // AN5: int tens (n?u =0 thì có th? ?? tr?ng)
                seg_next = (int_tens == 0) ? 7'b1111111 : seg7_encode_digit(int_tens);
                an_next  = 8'b1101_1111;
            end

            default: begin
                seg_next = 7'b1111111;
                an_next  = 8'b1111_1111;
            end
        endcase
    end

    always @(posedge sys_clk or posedge rst) begin
        if (rst) begin
            seg <= 7'b1111111;
            an  <= 8'b1111_1111;
        end else begin
            seg <= seg_next;
            an  <= an_next;
        end
    end

endmodule
