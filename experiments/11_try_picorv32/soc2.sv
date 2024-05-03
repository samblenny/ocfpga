// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny

// Minimal SoC with PicoRV32 and a UART

// IO ports are r0.2.1 OrangeCrab 85F signal names
module soc1(
  output logic led_r,    // RBG LED red (active low)
  output logic led_g,    // RBG LED green (active low)
  output logic led_b,    // RBG LED blue (active low)
  output logic io_1,     // Feather TX

  inout  logic io_sda,
  inout  logic io_scl,
  inout  logic io_5,
  inout  logic io_6,
  inout  logic io_9,
  inout  logic io_10,
  inout  logic io_11,
  inout  logic io_12,

  input  logic io_a0,
  input  logic io_a1,
  input  logic io_a2,
  input  logic io_a3,
  input  logic io_a4,
  input  logic io_a5,
  input  logic io_mosi,
  input  logic io_miso,
  input  logic io_0,     // Feather RX
  input  logic io_13,

  input        ref_clk,  // OSC1 OUT 48 MHz
);

// picorv32_wb interface
logic        trap;
logic        wb_rst_i = 1'b0;
logic [31:0] wbm_adr_o;
logic [31:0] wbm_dat_o;
logic [31:0] wbm_dat_i;
logic        wbm_we_o;
logic  [3:0] wbm_sel_o;
logic        wbm_stb_o;
logic        wbm_ack_i;
logic        wbm_cyc_o;
logic        pcpi_valid;  // out
logic [31:0] pcpi_insn;   // out
logic [31:0] pcpi_rs1;    // out
logic [31:0] pcpi_rs2;    // out
logic        pcpi_wr;     // in
logic [31:0] pcpi_rd;     // in
logic        pcpi_wait;   // in
logic        pcpi_ready;  // in
logic [31:0] irq;         // in
logic [31:0] eoi;         // out
logic        trace_valid; // out
logic [35:0] trace_data;  // out
logic        mem_instr;   // out

// picorv32_wb cpu(
//   .trap,
//   .wb_rst_i,
//   .wb_clk_i    (ref_clk),
//   .wbm_adr_o,
//   .wbm_dat_o,
//   .wbm_dat_i,
//   .wbm_we_o,
//   .wbm_sel_o,
//   .wbm_stb_o,
//   .wbm_ack_i,
//   .wbm_cyc_o,
//   .pcpi_valid,
//   .pcpi_insn,
//   .pcpi_rs1,
//   .pcpi_rs2,
//   .pcpi_wr,
//   .pcpi_rd,
//   .pcpi_wait,
//   .pcpi_ready,
//   .irq,
//   .eoi,
//   .trace_valid,
//   .trace_data,
//   .mem_instr
// );


// Wishbone read cycle one-hot state machine
localparam RX_IDLE    = 4'h1;
localparam RX_WAIT    = 4'h2;
localparam RX_CALLBK1 = 4'h4;
localparam RX_CALLBK2 = 4'h8;
logic [3:0] rx_state = RX_IDLE;

// 19200 baud async serial UART
localparam UART1_ADR = 32'h0FF;
uart1 #(
  .ADR      (UART1_ADR),
) uart1_inst(
  // Wishbone outputs
  .dat_o    (wbm_dat_i),
  .ack_o    (wbm_ack_i),
  // Wishbone inputs
  .clk_48_i (ref_clk),
  .rst_i    (wb_rst_i),
  .adr_i    (wbm_adr_o),
  .dat_i    (wbm_dat_o),
  .we_i     (wbm_we_o),
  .stb_i    (wbm_stb_o),
  .cyc_i    (wbm_cyc_o),
  .sel_i    (wbm_sel_o),
  // GPIO
  .tx_o     (io_1),       // TX pin follows UART tx net
  .rx_i     (io_0),       // RX pin drives UART rx net
  // Interrupt
  .irq_o    (irq_rx),
);

// uart1 IO
reg [7:0] rx_data = 8'b0;
reg [7:0] tx_data = 8'h54;  // 0x41='A' 0x54='T'
logic     irq_rx;

// Start with LED turned off
reg [2:0] led_rgb_n = 3'b111;
assign led_r  = led_rgb_n[2];  // LED Red, active low
assign led_g  = led_rgb_n[1];  // LED Green, active low
assign led_b  = led_rgb_n[0];  // LED Blue, active low

// Reset state
reg [1:0] rst_state = 2'b11;

//////////////////////////////////////////////////////////
//// Debug pins for logic analyzer ///////////////////////
//////////////////////////////////////////////////////////
reg [2:0] dbg = 3'b111;
assign io_5  = dbg[0];
assign io_6  = dbg[1];
assign io_9  = dbg[2];
/////////////////////////////////////////////////////////

// Top level state machine
always_ff @(posedge ref_clk) begin: main

  // Reset circuit
  unique case (rst_state)
    2'b11:   rst_state <= 2'b10;
    2'b10:   rst_state <= 2'b00;
    default: rst_state <= 2'b00;
  endcase
  wb_rst_i <= rst_state[1];

  // Respond to serial RX interrupt by reading byte from UART (wishbone read
  // cycle) then echoing that byte back over the UART (wishbone write cycle)
  unique case (rx_state)
    RX_IDLE: begin
        if (irq_rx) begin
          // Start a UART read cycle
          wbm_adr_o <= UART1_ADR;
          wbm_sel_o <= 3'd0;
          wbm_we_o  <= 1'b0;   // 0 for read
          wbm_stb_o <= 1'b1;
          wbm_cyc_o <= 1'b1;
          rx_state  <= RX_WAIT;
        end else begin
          rx_state  <= RX_IDLE;
        end
      end
    RX_WAIT: begin
        if (wbm_ack_i) begin
          // Got UART read ACK, so latch the UART CSR data
          wbm_stb_o <= 1'b0;
          wbm_cyc_o <= 1'b0;
          // Unpack the CSR
          rx_data  <= wbm_dat_i[7:0];
          rx_state <= RX_CALLBK1;
        end else begin
          rx_state <= RX_WAIT;
        end
      end
    RX_CALLBK1: begin
        // Set up a write cycle to echo the received data
        if (wbm_ack_i) begin
          rx_state <= RX_CALLBK1;   // Wait if ACK hasn't dropped yet
        end else begin
          wbm_dat_o <= rx_data;     // Echo RX byte if UART is ready
          wbm_adr_o <= UART1_ADR;
          wbm_sel_o <= 3'd0;
          wbm_we_o  <= 1'b1;
          wbm_stb_o <= 1'b1;
          wbm_cyc_o <= 1'b1;
          rx_state  <= RX_CALLBK2;
        end
      end
    RX_CALLBK2: begin
        // End the write cycle
        wbm_stb_o <= 1'b0;
        wbm_cyc_o <= 1'b0;
        rx_state  <= RX_IDLE;
      end
    default: begin
        rx_state <= RX_IDLE;
      end
  endcase

  // Status LED
  led_rgb_n[2] <= io_0 & io_1;  // Red LED shows TX or RX activity

end: main

endmodule
