# 07 Try Tigard JTAG


## Goals

1. Mount Tigard and wire it up to the OrangeCrab 85F

2. Try `ecpprog` and `openOCD` with Tigard JTAG interface

3. Try `screen` with Tigard UART, capturing TX pin on logic analyzer


## Results

1. New dev rig with OrangeCrab 85F, logic analyzer, and Tigard looks like this:

   ![OrangeCrab, Tigard, and logic analyzer mounted in a sandwich of Tamiya universal plates, with lots of wires](07_tigard_with_wires.jpeg)

2. ... *(work in progress)*


## Lab Notes

1. I took apart my old dev rig and added another universal plate to make room
   for the Tigard. The new rig is a sandwich of Tamiya universal plates joined
   with M3 nylon standoffs. The logic analyzer is in the middle with the Tigard
   and OrangeCrab on the top.

   Logic analyzer wiring is the same as before. Tigard UART and JTAG wiring are
   new:

   | Tigard UART | Tigard JTAG  | Logic 8 | OrangeCrab | Feather Spec |
   | ----------- | ------------ | ------- | ---------- | ------------ |
   |             |          GND |         | GND (jtag) |              |
   |             |          TCK |         | TCK        |              |
   |             |          TDI |         | TDO        |              |
   |             |          TDO |         | TDI        |              |
   |             |          TMS |         | TMS        |              |

   | Tigard UART | Tigard JTAG  | Logic 8 | OrangeCrab | Feather Spec |
   | ----------- | ------------ | ------- | ---------- | ------------ |
   |             |              |         | RST        | Rst          |
   |        VTGT |         VTGT |         | 3V3        | 3.3V         |
   |             |              |         | Aref       | Aref         |
   |             |              | GND0-7  | GND        | GND          |
   |             |              |         | A0         | A0           |
   |             |              |         | A1         | A1           |
   |             |              |         | A2         | A2           |
   |             |              |         | A3         | A3           |
   |             |              |         | A4         | A4 / D24     |
   |             |              |         | A5         | A5 / D25     |
   |             |              |         | SCK        | SCK          |
   |             |              |         | MOSI       | MO           |
   |             |              |         | MISO       | MI           |
   |          TX |              | 0       | 0          | RX / D0      |
   |          RX |              | 1       | 1          | TX / D1      |
   |         GND |              |         | GND        | GND          |

   | Tigard UART | Tigard JTAG  | Logic 8 | OrangeCrab | Feather Spec |
   | ----------- | ------------ | ------- | ---------- | ------------ |
   |             |              | 2       | SDA        | SDA          |
   |             |              | 3       | SCL        | SCL          |
   |             |              | 4       | 5          | D5           |
   |             |              | 5       | 6          | D6           |
   |             |              | 6       | 9          | D9           |
   |             |              | 7       | 10         | D10          |
   |             |              |         | 11         | D11          |
   |             |              |         | 12         | D12          |
   |             |              |         | 13         | D13          |

   Also see: https://learn.adafruit.com/adafruit-feather/feather-specification

2. Tigard switches are set for `VTGT` (level shifters) and `JTAG SPI`.
