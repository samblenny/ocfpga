// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny

// Minimal SoC with PicoRV32 and a UART

// IO ports are r0.2.1 OrangeCrab 85F signal names
module soc1(
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

// uart1 IO
logic       tx;
logic       tx_busy;
logic [7:0] tx_data = 8'h54;  // 0x41='A' 0x54='T'
logic       tx_w    = 1'b0;   // write not asserted

// picorv32 outputs
logic        trap;
logic        mem_valid;
logic        mem_instr;
logic        mem_ready;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [ 3:0] mem_wstrb;
logic        mem_la_read;
logic        mem_la_write;
logic [31:0] mem_la_addr;
logic [31:0] mem_la_wdata;
logic [ 3:0] mem_la_wstrb;
logic        pcpi_valid;
logic [31:0] pcpi_insn;
logic [31:0] pcpi_rs1;
logic [31:0] pcpi_rs2;
logic [31:0] eoi;
logic        trace_valid;
logic [35:0] trace_data;

// picorv32 inputs
logic        resetn    =  1'b1;
logic        mem_ready =  1'b1;
logic [31:0] mem_rdata = 32'b0;
logic        pcpi_wr;
logic [31:0] pcpi_rd;
logic        pcpi_wait;
logic        pcpi_ready;
logic [31:0] irq;

picorv32 picorv32(
  .clk           (ref_clk),
  .resetn,
  .trap,
  .mem_valid,
  .mem_instr,
  .mem_ready,

  .mem_addr,
  .mem_wdata,
  .mem_wstrb,
  .mem_rdata,

  .mem_la_read,
  .mem_la_write,
  .mem_la_addr,
  .mem_la_wdata,
  .mem_la_wstrb,

  .pcpi_valid,
  .pcpi_insn,
  .pcpi_rs1,
  .pcpi_rs2,
  .pcpi_wr,
  .pcpi_rd,
  .pcpi_wait,
  .pcpi_ready,

  .irq,
  .eoi,

  .trace_valid,
  .trace_data,
);

// 19200 baud async serial UART
uart1 uart1_inst(
  .tx,
  .tx_busy,
  .tx_data,
  .tx_w,
  .clk_48   (ref_clk),
);

// Top level state machine
always_ff @(posedge ref_clk) begin: main

  // Strobe tx_w every 1000 ms
  if (timer == 0) begin
    tx_w <= 1'b1;
    timer <= OVERFLOW_1S;
  end else begin
    tx_w <= 1'b0;
    timer <= timer + TIMER_INC;
  end

  // Update IO pins
  led_r <= io_0 & ~tx_busy;  // Red LED shows both TX and RX activity
  led_b <= 1'b1;             // Blue LED off
  led_g <= 1'b1;             // Green LED off
  io_1 <= tx;                // TX pin driven by UART output

end: main

endmodule
