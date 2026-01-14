`timescale 1ns/1ps

module debounced #(
    parameter DEBOUNCE_MS = 20,        // Th?i gian debounce (ms)
    parameter CLK_FREQ_MHZ = 100       // T?n s? clock (MHz)
) (
    input  wire clk,
    input  wire reset,
    input  wire sw_in,     // Switch input (có th? b? d?i)
    output reg  sw_out,    // Output ?ã debounce
    output reg  sw_rise,   // Xung 1 chu k? khi có rising edge
    output reg  sw_fall    // Xung 1 chu k? khi có falling edge
);

    // ======================================================
    // Tính toán th?i gian debounce
    // ======================================================
    localparam DEBOUNCE_CYCLES = DEBOUNCE_MS * CLK_FREQ_MHZ * 1000; // 20ms = 2,000,000 cycles
    localparam COUNTER_WIDTH = $clog2(DEBOUNCE_CYCLES + 1);
    
    // ======================================================
    // Các register n?i b?
    // ======================================================
    reg [COUNTER_WIDTH-1:0] counter;
    reg [2:0] sw_sync;          // Triple synchronizer (ch?ng metastability)
    reg sw_debounced_reg;
    reg sw_debounced_prev;
    
    // ======================================================
    // Synchronizer (b?t bu?c cho input async)
    // ======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sw_sync <= 3'b000;
        end else begin
            sw_sync <= {sw_sync[1:0], sw_in};
        end
    end
    
    wire sw_sync_wire = sw_sync[2];  // Tín hi?u ?ã sync
    
    // ======================================================
    // Debounce logic chính
    // ======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            sw_debounced_reg <= 1'b0;
            sw_debounced_prev <= 1'b0;
            sw_out <= 1'b0;
            sw_rise <= 1'b0;
            sw_fall <= 1'b0;
        end else begin
            // Default values
            sw_rise <= 1'b0;
            sw_fall <= 1'b0;
            
            // L?u giá tr? c?
            sw_debounced_prev <= sw_debounced_reg;
            
            if (sw_sync_wire == sw_debounced_reg) begin
                // Tín hi?u ?n ??nh, reset counter
                counter <= 0;
            end else begin
                // Tín hi?u thay ??i
                if (counter >= DEBOUNCE_CYCLES) begin
                    // ?ã ??i ?? th?i gian debounce
                    sw_debounced_reg <= sw_sync_wire;  // C?p nh?t giá tr? m?i
                    counter <= 0;                      // Reset counter
                    
                    // Edge detection
                    if (sw_sync_wire && !sw_debounced_prev) begin
                        sw_rise <= 1'b1;  // Rising edge
                    end else if (!sw_sync_wire && sw_debounced_prev) begin
                        sw_fall <= 1'b1;  // Falling edge
                    end
                end else begin
                    // Ch?a ?? th?i gian, ti?p t?c ??m
                    counter <= counter + 1;
                end
            end
            
            // Output luôn b?ng giá tr? ?ã debounce
            sw_out <= sw_debounced_reg;
        end
    end

endmodule