// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny

// IO ports are r0.2.1 OrangeCrab 85F signal names
module oc85f(
  output logic led_r,        // RBG LED red (active low)
  output logic led_g,        // RBG LED green (active low)
  output logic led_b,        // RBG LED blue (active low)
  output logic io_1,         // Feather TX

  input  logic io_a0,
  input  logic io_a1,
  input  logic io_a2,
  input  logic io_a3,
  input  logic io_a4,
  input  logic io_a5,
  input  logic io_mosi,
  input  logic io_miso,
  input  logic io_0,     // Feather RX
  input  logic io_sda,
  input  logic io_scl,
  input  logic io_5,
  input  logic io_6,
  input  logic io_9,
  input  logic io_10,
  input  logic io_11,
  input  logic io_12,
  input  logic io_13,

  input        ref_clk,  // OSC1 OUT 48 MHz
);

// Constants for a timer that overflows at 1000 ms
//   19208864 = (2 ** 26) - 48e6
localparam TIMER_WIDE = 26;
localparam TIMER_MSB = 25;
localparam TIMER_INC = 26'd1;
localparam OVERFLOW_1S = 26'd19208864;

logic [25:0] timer = 26'b0;

logic       tx_n;
logic       tx_busy_n;
logic [7:0] tx_data    = 8'h54;  // 0x41='A' 0x54='T'
logic       tx_w_n     = 1'b1;   // write not asserted

// 19200 baud async serial UART
uart uart0(
  .tx_n      (tx_n),
  .tx_busy_n,
  .tx_data,
  .tx_w_n,
  .clk_48    (ref_clk),
);

assign led_b = 1'b1;  // Blue LED off
assign led_g = 1'b1;  // Green LED off

// Top level state machine
always @(posedge ref_clk) begin: main

  // Toggle tx_w_n every 1000 ms
  if (timer == 0) begin
    tx_w_n <= 1'b0;
    timer <= OVERFLOW_1S;
  end else begin
    tx_w_n <= 1'b1;
    timer <= timer + TIMER_INC;
  end

  // Update pins
  led_r <= io_0 & tx_n;  // Red LED shows both TX and RX activity
  io_1 <= tx_n;          // TX pin driven by UART output
end: main

endmodule
