// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
//
// uart
//     An async serial uart with default baud rate of 19200
//
// Baud rate timings at 48 MHz:
//
//   |   baud | period (W) | log2(W) | seed = (2**13)-W | seed + period |
//   | ------ | ---------- | ------- | ---------------- | ------------- |
//   |   9600 |   5000.000 |      13 |             3192 |        8192.0 |
//   |  19200 |   2500.000 |      12 |             5692 |        8192.0 |
//   | 115200 |    416.667 |       9 |             7775 |        8191.7 |
//
module uart1 #(
  // Wishbone address for this UART
  parameter ADR = 32'h0FF,

  // Timer seed so the 13-bit timer will overflow at baud rate
  // (default is 19200 baud, see table above)
  parameter TIMER_SEED = 13'd5692
)
(
  // Wishbone outputs
  output [31:0] dat_o,     // data out (peripheral -> controller)
  output        ack_o,     // ack

  // Wishbone inputs
  input         clk_48_i,  // 48 MHz clock
  input         rst_i,     // reset, active high
  input  [31:0] adr_i,     // address
  input  [31:0] dat_i,     // data in (controller -> peripherial)
  input         we_i,      // write enable
  input         stb_i,     // strobe
  input         cyc_i,     // cycle
  input   [3:0] sel_i,     // byte select (IGNORED): 3:[31:24]..0:[7:0]

  // GPIO
  output        tx_o,      // async serial TX net
  input         rx_i,      // async serial RX net
);

// States for transmit state machine (yosys seems to not like enum)
localparam IDLE  = 11'h001;
localparam START = 11'h002;
localparam D7    = 11'h004;
localparam D6    = 11'h008;
localparam D5    = 11'h010;
localparam D4    = 11'h020;
localparam D3    = 11'h040;
localparam D2    = 11'h080;
localparam D1    = 11'h100;
localparam D0    = 11'h200;
localparam STOP  = 11'h400;

reg    [7:0] tx_data_r;
reg   [31:0] rx_data_r;
logic [12:0] tx_timer;  // 13-bit timer, see baud rate table above
logic [10:0] tx_state;  // 11 states, one-hot encoded

// Main state machine
always_ff @(posedge clk_48_i or posedge rst_i) begin: main

  // Reset
  if (rst_i) begin
    tx_data_r <= 8'h0;
    rx_data_r <= 32'h00000041; // low-byte: 'A'
    tx_state <= IDLE;
    tx_timer <= TIMER_SEED;
    tx_o = 1'b1;
  end else begin: not_reset

  // Wishbone read/write decoder
  if ((adr_i == ADR) && stb_i && cyc_i) begin
    ack_o <= stb_i;  // Note: Ack is synchronous with the stuff below
    if (we_i) begin
      // Write: enqueue TX data from low byte of data word
      // (CAUTION: silently ignore writes when TX state machine is busy)
      // (CAUTION: wishbone sel_i is ignored, this always uses low-byte)
      if (tx_state == IDLE) begin
        tx_data_r <= dat_i[7:0];  // latch tx data
        tx_state <= START;        // move state out of IDLE (enable timer)
        tx_timer <= TIMER_SEED;   // prepare timer to overflow at baud rate
      end
    end else begin
      // Read: drive RX data to low byte of data word
      dat_o <= rx_data_r;
    end
  end

  // TX state machine (state advances when baud rate timer overflows)
  if (tx_state != IDLE) begin
    if (tx_timer != 0) begin
      // Timer has not overflowed yet, so just increment the timer
      tx_timer <= tx_timer + 13'b1;
    end else begin
      // Timer just overflowed: reset timer and advance state
      tx_timer <= TIMER_SEED;
      unique case (tx_state)
        START:   tx_state <= D0;
        D0:      tx_state <= D1;
        D1:      tx_state <= D2;
        D2:      tx_state <= D3;
        D3:      tx_state <= D4;
        D4:      tx_state <= D5;
        D5:      tx_state <= D6;
        D6:      tx_state <= D7;
        D7:      tx_state <= STOP;
        default: tx_state <= IDLE;  // This stops the timer
      endcase
    end
  end

  // Drive TX net according to data register and current state
  unique case (tx_state)
    START:   tx_o <= 1'b0;          // start bit
    D0:      tx_o <= tx_data_r[0];  // data LSB
    D1:      tx_o <= tx_data_r[1];
    D2:      tx_o <= tx_data_r[2];
    D3:      tx_o <= tx_data_r[3];
    D4:      tx_o <= tx_data_r[4];
    D5:      tx_o <= tx_data_r[5];
    D6:      tx_o <= tx_data_r[6];
    D7:      tx_o <= tx_data_r[7];  // data MSB
    default: tx_o <= 1'b1;          // STOP or IDLE
  endcase

  end: not_reset
end: main

endmodule
