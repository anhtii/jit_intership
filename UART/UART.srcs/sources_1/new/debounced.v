module debounced (
    input  wire clk,
    input  wire reset,      
    input  wire sw_in,      
    output reg  sw_out      
);
    // 100ms @ 100MHz = 10_000_000
    parameter integer c_DEBOUNCE_LIMIT = 10_000_000;

    reg [23:0] counter;
    reg        sw_sync;     

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 24'd0;
            sw_sync <= 1'b0;
            sw_out  <= 1'b0;
        end else begin
            if (sw_in != sw_sync) begin
                sw_sync <= sw_in;
                counter <= 24'd0;
            end else if (counter < c_DEBOUNCE_LIMIT) begin
                counter <= counter + 1;
            end else begin
                sw_out <= sw_sync;
            end
        end
    end
endmodule
