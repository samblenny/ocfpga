// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
//
// uart
//     An async serial uart with default baud rate of 19200
//
// Baud rate timings at 48 MHz (for calculations, see baud_table.py):
//
//   |   baud |     period | timer_bits | timer_seed | seed + period |
//   | ------ | ---------- | ---------- | ---------- | ------------- |
//   |    300 | 160000.000 |         18 |     102144 |      262144.0 |
//   |   1200 |  40000.000 |         16 |      25536 |       65536.0 |
//   |   2400 |  20000.000 |         15 |      12768 |       32768.0 |
//   |   9600 |   5000.000 |         13 |       3192 |        8192.0 |
//   |  19200 |   2500.000 |         12 |       1596 |        4096.0 |
//   | 115200 |    416.667 |          9 |         95 |         511.7 |
//
module uart(
  output logic       tx_n,       // TX modulated async serial signal
  output logic       tx_busy_n,  // TX busy indicator
  input  logic [7:0] tx_data,    // Data to be sent (latched on write strobe)
  input  logic       tx_w_n,     // write strobe
  input  logic       clk_48
);

// Hardcode timer for 19200 baud
localparam TIMER_WIDE = 12;
localparam TIMER_MSB  = 11;
localparam TIMER_INC  = 12'd1;
localparam TIMER_SEED = 12'd1596;  // see "seed + period" in table above

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

reg   [7:0]         tx_data_r = 8'h0;
logic [TIMER_MSB:0] tx_timer  = 1'b1;
logic [10:0]        tx_state  = IDLE;

// Init
initial begin
  tx_n = 1'b1;
  tx_busy_n = 1'b1;
end

// Main state machine
always_ff @(posedge clk_48) begin: main

  if (tx_state == IDLE) begin
    // IDLE: wait for a TX write strobe
    if (!tx_w_n) begin
      tx_data_r <= tx_data;    // latch data to register
      tx_state <= START;       // move state out of IDLE
      tx_timer <= TIMER_SEED;  // set timer period to overflow at baud rate
    end
  end else begin
    // Not IDLE: state transitions are driven by baud rate timer
    if (tx_timer != 0) begin
      // Timer has not overflowed yet, so just increment the timer
      tx_timer <= tx_timer + TIMER_INC;
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

  // Set busy signal according to current state
  unique case (tx_state)
    IDLE:    tx_busy_n <= 1'b1;  // not busy
    default: tx_busy_n <= 1'b0;  // busy
  endcase

  // Set TX signal according to data register and current state
  unique case (tx_state)
    START:   tx_n <= 1'b0;          // start bit
    D0:      tx_n <= tx_data_r[0];  // data LSB
    D1:      tx_n <= tx_data_r[1];
    D2:      tx_n <= tx_data_r[2];
    D3:      tx_n <= tx_data_r[3];
    D4:      tx_n <= tx_data_r[4];
    D5:      tx_n <= tx_data_r[5];
    D6:      tx_n <= tx_data_r[6];
    D7:      tx_n <= tx_data_r[7];  // data MSB
    default: tx_n <= 1'b1;          // STOP or IDLE
  endcase

end: main

endmodule
