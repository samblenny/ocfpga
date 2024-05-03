// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
//
// uart
//     An async serial uart with default baud rate of 19200
//
// Baud rate timings use 48 MHz countdown timers, for example:
//
//   |   baud | period (W) | log2(W) | RX offset (W/2) |
//   | ------ | ---------- | ------- | --------------- |
//   |   9600 |   5000.000 |      13 |        2500.000 |
//   |  19200 |   2500.000 |      12 |        1250.000 |
//   | 115200 |    416.667 |       9 |         208.333 |
//
// dat_o CSR format:
//   | [31:8] unused | [7:0] rx_data |
//
// This UART is designed for RX data to be polled after irq_rx goes high.
// If irq_rx is low, the contents of dat_o[7:0] are undefined.
//
module uart1 #(
  // Wishbone address for this UART
  parameter ADR = 32'h0FF,

  // TIMER_SEED: 13-bit 48 MHz timer seed to reach 0 at the baud rate
  // (default is 19200 baud, see table above)
  parameter TIMER_SEED = 13'd2500,

  // RX_OFFSET: 13-bit 48 MHz timer seed for half of the baud rate. This is
  // used to offset the phase of RX sampling from the start bit's falling
  // edge to the expected mid-points of the data and framing bits.
  parameter RX_OFFSET  = 13'd1250,
)
(
  // Wishbone outputs...
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

  // Serial nets
  output logic  tx_o,      // async serial TX net
  input         rx_i,      // async serial RX net

  // Interrupt
  output logic  irq_o,     // interrupt indicating rx data is ready
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

// Timer constants
localparam TIMER_DEC = 13'sh1FFF;  // 13-bit wide 2's complement -1
localparam TIMER_ZERO = 13'h0;

// CSR for Wishbone reads
reg [31:0] csr;          // RX data is in [7:0] (only valid if irq_rx high)

// TX misc
reg    [7:0] tx_data_r;  // FIFO for TX data
logic [12:0] tx_timer;   // 13-bit timer, see baud rate table above
logic [10:0] tx_state;   // 11 states, one-hot encoded

// RX misc
reg    [8:0] rx_wave;    // reg to hold RX waveform samples (except stop bit)
reg          irq_rx;     // register to hold unacknowledged RX interrupt
logic [12:0] rx_timer;   // 13-bit timer, see baud rate table above
logic [10:0] rx_state;   // 11 states, one-hot encoded

// Interrupt
assign irq_o = irq_rx;

// Main state machine
always_ff @(posedge clk_48_i or posedge rst_i) begin: main

  // Reset
  if (rst_i) begin
    ack_o     =  1'bz;
    dat_o     =  32'bz;
    tx_data_r <= 8'h0;
    csr       <= 32'h0;
    tx_state  <= IDLE;
    tx_timer  <= TIMER_SEED;
    rx_wave   <= 8'b0;
    rx_state  <= IDLE;
    rx_timer  <= RX_OFFSET;
    tx_o      <= 1'b1;
    irq_rx    <= 1'b0;
  end else begin: not_reset

  // Wishbone read/write decoder
  // CAUTION: This uses continuous assignement ('=' instead of '<=') in several
  // spots in the attempt to avoid adding an extra wishbone bus clock tick to
  // every read or write cycle. It's possible this might lead to mysterious
  // data glitches some day (in that case, try switching it all to '<=').
  if ((adr_i == ADR) && cyc_i) begin
    ack_o = stb_i;
    unique case({stb_i, we_i})
      2'b11: begin
          // Strobe Write: enqueue TX data from low byte of data word
          // (CAUTION: silently ignore writes when TX state machine is busy)
          // (CAUTION: wishbone sel_i is ignored, this always uses low-byte)
          if (tx_state == IDLE) begin
            tx_data_r = dat_i[7:0];  // latch tx data
            tx_state <= START;       // move state out of IDLE (enable timer)
            tx_timer <= TIMER_SEED;  // prepare timer to overflow at baud rate
          end
          dat_o = 32'bz;
        end
      2'b10: begin
          // Strobe Read: drive RX data to low byte of data word
          dat_o = csr;
          irq_rx = 1'b0;  // clear RX ready IRQ
        end
      default: begin
          // !Strobe
          dat_o = 32'bz;
        end
    endcase
  end else begin
    // Address does not match or Cycle is low
    // CAUTION: This gave me trouble. ACK must be released, not latched!
    ack_o = 1'bz;
    dat_o = 32'bz;
  end

  // TX state machine
  if (tx_state != IDLE) begin
    if (tx_timer != TIMER_ZERO) begin
      // Timer has not zeroed out yet, so decrement timer
      tx_timer <= tx_timer + TIMER_DEC;
    end else begin
      // Timer hit zero: reset timer and advance state
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

  // RX state machine
  if (rx_state == IDLE) begin
    if (~rx_i) begin            // Start sampling wave on RX falling edge
      rx_timer <= RX_OFFSET;    // Use 1/2 period to get phase offset
      rx_state <= START;
    end
  end else begin: not_idle
    if (rx_timer != TIMER_ZERO) begin
      // Timer has not zeroed out yet, so decrement timer
      rx_timer <= rx_timer + TIMER_DEC;
    end else begin: timer_zero
      // Timer hit zero: sample waveform and advance state
      rx_timer <= TIMER_SEED;
      unique case (rx_state)
        START:  begin rx_state <= D0;   rx_wave[0] <= rx_i; end  // start bit
        D0:     begin rx_state <= D1;   rx_wave[1] <= rx_i; end  // LSB
        D1:     begin rx_state <= D2;   rx_wave[2] <= rx_i; end
        D2:     begin rx_state <= D3;   rx_wave[3] <= rx_i; end
        D3:     begin rx_state <= D4;   rx_wave[4] <= rx_i; end
        D4:     begin rx_state <= D5;   rx_wave[5] <= rx_i; end
        D5:     begin rx_state <= D6;   rx_wave[6] <= rx_i; end
        D6:     begin rx_state <= D7;   rx_wave[7] <= rx_i; end
        D7:     begin rx_state <= STOP; rx_wave[8] <= rx_i; end  // MSB
        STOP:  begin
          // CAUTION: This uses (~start_bit && stop_bit) as a cheap frame
          // validity check. Sampled waveforms that fail the check will be
          // silently ignored.
          rx_state <= IDLE;              // stop the timer
          if (~rx_wave[0] & rx_i) begin  // start bit low and stop bit high?
            csr[7:0] <= rx_wave[8:1];    //   enqueue the data bits
            irq_rx <= 1'b1;              //   raise interrupt
          end
        end
        default: rx_state <= IDLE;
      endcase
    end: timer_zero
  end: not_idle

  end: not_reset
end: main

endmodule
