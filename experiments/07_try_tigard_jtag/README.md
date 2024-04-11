# 07 Try Tigard JTAG


## Goals

1. Mount Tigard and wire it up to the OrangeCrab 85F

2. Try `ecpprog` and `openOCD` with Tigard JTAG interface

3. Try `screen` and `tio` with Tigard UART, capturing TX pin on logic analyzer


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

3. Install `openocd`, `screen`, and `tio`:

   ```bash
   $ sudo apt install openocd
   ```

4. Researching openOCD configs...

   - [orangecrab-hardware/contrib/openocd/orangecrab-85f.cfg](https://github.com/orangecrab-fpga/orangecrab-hardware/blob/f176a3f87ea1b35bee12e4b1aa4148b1dfcae233/contrib/openocd/orangecrab-85f.cfg)
   does not specify the JTAG probe it was intended for, but the USB IDs are
   for something based on the FTDI FT2232H/D chip.

   - [tigard-tools/tigard/README.md](https://github.com/tigard-tools/tigard/tree/d822c4e9425e1fd5c4f62631a532aa64946c526c?tab=readme-ov-file#jtag-debug-on-jtag-or-cortex-header)
   gives an example openOCD config for Tigard JTAG.

   - OpenOCD [HTML documentation](https://openocd.org/doc/html/index.html)

5. OpenOCD docs [Running](https://openocd.org/doc/html/Running.html) page notes:

   - `openocd` looks for `openocd.cfg` config file in a search path including
     the current directory, `$HOME/.config/openocd`, and `$HOME/.openocd`..

   - Refer to [OpenOCD Project Setup](https://openocd.org/doc/html/OpenOCD-Project-Setup.html)
     page for info on default config files

6. [OpenOCD Project Setup](https://openocd.org/doc/html/OpenOCD-Project-Setup.html)
   page notes:

   OpenOCD scripts directory is usually `/usr/share/openocd/scripts` on Linux
   so, let's see what's there...

    ```bash
    $ cd /usr/share/openocd/scripts
    $ find * -type f | grep -i 'tigard\|orange\|ecp5'
    fpga/lattice_ecp5.cfg
    interface/ftdi/tigard.cfg
    ```

   Looks like openocd already knows about the ECP5 and Tigard (v1.1). The
   contents of `interface/ftdi/tigard.cfg` are mostly the same as the example
   from `tigard-tools/README.md`, with the exception of how the config keywords
   are spelled. For example, the readme uses `ftdi_vid_pid` and
   `ftdi_layout_init` while the distro .cfg file uses `ftdi vid_pid` and
   `ftdi layout_init`. Potentially important differences:

   - README includes `adapter_khz 2000`

   - distro .cfg includes `reset_config ...` with a comment about using
     push-pull IO for reset modes rather than open-drain

   Comparing `fpga/lattice_ecp5.cfg` (ECP5 distro config) with
   `orangecrab-hardware/contrib/openocd/orangecrab-85f.cfg` (orangecrab
   config), the main differences are:

   - orangecrab config includes settings for FTDI 0403:6010 (FT2232H), but they
     don't match Tigard (channel 0 instead of 1, different layout_init values)

   - orangecrab config sets `adapter speed 5000`

   - ECP5 distro config includes `expected-id` values for many ECP5 devices
     while orangecrab config only includes one 85F device
