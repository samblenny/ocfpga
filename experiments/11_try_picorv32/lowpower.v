// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny

// Things I tried that had no measurable effect:
// 1. `ram_reset_inv <= 1'b0;`
// 2. `ram_cke <= 1'b0;`

// IO ports are r0.2.1 OrangeCrab 85F signal names
module lowpower(
  output logic led_r,          // RBG LED red (active low)
  output logic led_g,          // RBG LED green (active low)
  output logic led_b,          // RBG LED blue (active low)
  output logic ram_reset_inv,  // DRAM reset pin (active low)
  output logic io_1,           // Feather TX

  // ECP5 DAC for analog input does not seem to be supported by yosys (?).
  // So... just configure the analog mux pins to avoid leaking current.
  //
  output logic adc_ctrl0,    // part of an RC filter on ADC_SENSE_LO
  output logic adc_ctrl1,    // 74HC4067BQ mux E# pin (high to disable mux)
  output logic adc_mux0,     // mux source select
  output logic adc_mux1,     // mux source select
  output logic adc_mux2,     // mux source select
  output logic adc_mux3,     // mux source select

  input  logic adc_sense_lo,
  input  logic adc_sense_hi,

  // These are Feather input pins, mostly with pulldowns in the lpf file
  input  logic io_a0,
  input  logic io_a1,
  input  logic io_a2,
  input  logic io_a3,
  input  logic io_a4,
  input  logic io_a5,
  input  logic io_mosi,
  input  logic io_miso,
  input  logic io_0,         // Feather RX (active low)

  input  logic io_sda,       // Feather I2C SDA
  input  logic io_scl,       // Feather I2C SCL
  input  logic io_5,
  input  logic io_6,
  input  logic io_9,
  input  logic io_10,
  input  logic io_11,
  input  logic io_12,
  input  logic io_13,

  input        ref_clk,      // OSC1 OUT 48 MHz
);

initial begin
  led_g = 1'b1;          // LED green off
  led_b = 1'b1;          // LED blue off
  io_sda = 1'bz;         // I2C SDA highz (yosys warns this may not work)
  io_scl = 1'bz;         // I2C SCL highz (yosys warns this may not work)

  // Configure analog mux for low leakage current (mux common to GND)
  adc_ctrl0 <= 1'b0;   // Ground the RC filter on ADC_SENSE_LO
  adc_ctrl1 <= 1'b0;   // 74HC4067BQ mux E# pin (low enables mux)
  adc_mux0 <= 1'b0;    // mux source select (all low for Y0=GND)
  adc_mux1 <= 1'b0;    // mux source select (all low for Y0=GND)
  adc_mux2 <= 1'b0;    // mux source select (all low for Y0=GND)
  adc_mux3 <= 1'b0;    // mux source select (all low for Y0=GND)

  // This is an attempt to put the DRAM chip in reset. It does not seem to
  // have any measurable effect on current draw.
  ram_reset_inv = 1'b0;  // Hold DRAM in reset
end

// This does serial loopback with an RX activity monitor LED.
always_comb begin
  io_1 <= io_0;    // TX pin follows RX pin
  led_r <= io_0;   // LED red follows RX pin
end


// This is an attempt to instantiate a PLL and put it in standby. It does
// not seem to have any measurable effect on current draw.
logic clk0_o;
logic locked;
EHXPLLL #(
  .PLLRST_ENA("DISABLED"),
  .INTFB_WAKE("DISABLED"),
  .STDBY_ENABLE("ENABLED"),
  .DPHASE_SOURCE("DISABLED"),
  .OUTDIVIDER_MUXA("DIVA"),
  .OUTDIVIDER_MUXB("DIVB"),
  .OUTDIVIDER_MUXC("DIVC"),
  .OUTDIVIDER_MUXD("DIVD"),
  .CLKI_DIV(1),
  .CLKOP_ENABLE("ENABLED"),
  .CLKOP_DIV(12),
  .CLKOP_CPHASE(5),
  .CLKOP_FPHASE(0),
  .FEEDBK_PATH("CLKOP"),
  .CLKFB_DIV(1)
) pll_i (
  .RST(1'b0),
  .STDBY(1'b1),
  .CLKI(ref_clk),
  .CLKOP(clk0_o),
  .CLKFB(clk0_o),
  .CLKINTFB(),
  .PHASESEL0(1'b0),
  .PHASESEL1(1'b0),
  .PHASEDIR(1'b1),
  .PHASESTEP(1'b1),
  .PHASELOADREG(1'b1),
  .PLLWAKESYNC(1'b0),
  .ENCLKOP(1'b0),
  .LOCK(locked)
);
endmodule
