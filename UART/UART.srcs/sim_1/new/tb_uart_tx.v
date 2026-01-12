`timescale 1ns/1ps

module tb_uart_tx;

    // -----------------------------
    // Testbench signals
    // -----------------------------
    reg         clk;
    reg         rst;
    reg         tx_dv;
    reg [7:0]   tx_byte;

    wire        tx_serial;
    wire        tx_active;
    wire        tx_done;

    wire        rx_dv;
    wire [7:0]  rx_byte;

    // -----------------------------
    // Clock: 100 MHz (10 ns period)
    // -----------------------------
    always #5 clk = ~clk;

    // -----------------------------
    // UART TX DUT
    // -----------------------------
    uart_txd dut_tx (
        .i_Clock(clk),
        .i_Reset(rst),
        .i_Clocks_per_Bit(7'd100), // 1 Mbps @100MHz
        .i_Tx_DV(tx_dv),
        .i_Tx_Byte(tx_byte),
        .o_Tx_Serial(tx_serial),
        .o_Tx_Active(tx_active),
        .o_Tx_Done(tx_done)
    );

    // -----------------------------
    // UART RX DUT (loopback)
    // -----------------------------
    uart_rxd dut_rx (
        .i_Clock(clk),
        .i_Reset(rst),
        .i_Clocks_per_Bit(7'd100), // SAME baud
        .i_Rx_Serial(tx_serial),   // <<< LOOPBACK
        .o_Rx_DV(rx_dv),
        .o_Rx_Byte(rx_byte)
    );

    // -----------------------------
    // Test sequence
    // -----------------------------
    initial begin
        // init
        clk      = 0;
        rst      = 1;
        tx_dv   = 0;
        tx_byte = 8'h00;

        // reset
        #100;
        rst = 0;

        // wait a bit
        #100;

        // send 1 byte: 
        tx_byte = 8'h61;
        tx_dv   = 1;
        #10;            // 1 clock pulse
        tx_dv   = 0;

        // wait until RX gets data
        wait (rx_dv == 1);

        // check result
        if (rx_byte == 8'h61)
            $display("PASS: RX received 0x%h", rx_byte);
        else
            $display("FAIL: RX received 0x%h", rx_byte);

        // wait a little more
        #1000;
        $stop;
    end

endmodule
