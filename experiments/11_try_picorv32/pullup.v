// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright 2024 Sam Blenny

module exp11A(
  input  ref_clk,  // OSC1 OUT 48 MHz
  input  io_0,     // Feather RX (active low)

  output io_1,     // Feather TX (active low)
  output led_r,    // OrangeCrab RBG LED red (active low)
  output led_g,    // OrangeCrab RBG LED green (active low)
  output led_b,    // OrangeCrab RBG LED blue (active low)

  inout  io_sda,   // Feather I2C SDA
  inout  io_scl,   // Feather I2C SCL
);

initial begin
  led_r <= 1'b1;   // LED red off
  led_g <= 1'b1;   // LED green off
  led_b <= 1'b1;   // LED blue off
  io_sda <= 1'bz;  // I2C SDA high-impedance (pullup from lpf file)
  io_scl <= 1'bz;  // I2C SCL high-impedance (pullup from lpf file)
end

// This does serial loopback with an RX activity monitor LED.
always_comb begin
  io_1 <= io_0;      // TX pin follows RX pin (push-pull)
  led_r <= io_0;     // LED red follows RX pin (push-pull)
  if (!io_0) begin   // SDA follows RX pin (open drain with pullup)
    io_sda <= 1'b0;
  end else begin
    io_sda <= 1'bz;
  end
end

endmodule
