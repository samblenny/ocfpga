# 04 Try Prebuilt Firmware

Work in progress. See [download-firmware.pl](download-firmware.pl).

Goals:

1. Figure out how, if possible, to read the factory LED blinking DFU firmware
   image

2. Figure out how, if possible, to write other prebuilt firmware images from

   https://github.com/orangecrab-fpga/production-test-sw/tree/main/prebuilt

   (I'm unsure if the factory test bitstreams can be flashed without JTAG)

3. Send some kind of output to one of the OrangeCrab pins then capture and
   decode that on my logic analyzer. For example, maybe some of this stuff
   would work:
   - https://github.com/orangecrab-fpga/orangecrab-examples


## References

1. The OrangeCrab bootloader is based on a fork of the Fomu bootloader. The
   source code is here (OrangeCrab branch):
   - https://github.com/gregdavill/foboot/tree/OrangeCrab

   The README says a command called `dfu-util` can be used to read and write
   the DFU device's flash chip.

2. These links are for Debian Bookworm's `dfu-util` package (version 0.11-1):
   - package: https://packages.debian.org/bookworm/dfu-util
   - manpage: https://manpages.debian.org/bookworm/dfu-util/dfu-util.1.en.html

3. These links are for Ubuntu 22.04 LTS `dfu-util` package (version 0.9-1):
   - package: https://packages.ubuntu.com/jammy/dfu-util
   - manpage: https://manpages.ubuntu.com/manpages/jammy/en/man1/dfu-tool.1.html

4. dfu-util homepage:
   - https://dfu-util.sourceforge.net/


## Install Dependencies

1. Install Debian package for `dfu-util` (should also work for Ubuntu):

    ```
    $ sudo apt install dfu-tool
    $ dfu-util --version | grep '^dfu-util'
    dfu-util 0.11
    ```

2. Add a udev to give user accounts in the plugdev group +rw permissions for
   the OrangeCrab DFU device:

    ```
    $ cat <<EOF | sudo tee /etc/udev/rules.d/99-OrangeCrab-DFU.rules
    # OrangeCrab DFU bootloader (hold down btn0 button while plugging in USB)
    ACTION=="add", SUBSYSTEM=="usb", \
     ATTRS{idVendor}=="1209", ATTRS{idProduct}=="5af0", GROUP="plugdev", MODE="664"
    EOF
    ```


## Notes on trying out dfu-util...

1. Try listing devices:

    ```
    $ man dfu-util
    $ dfu-util --list 2>&1 | perl -ne 'print if $n++ > 6'
    Deducing device DFU version from functional descriptor length
    dfu-util: Cannot open DFU device 05ac:8289 found on devnum 6 (LIBUSB_ERROR_ACCESS)
    dfu-util: Cannot open DFU device 1209:5af0 found on devnum 7 (LIBUSB_ERROR_ACCESS)
    ```

2. That error looks like I'm missing a udev rule. So, try adding a rule that
   gives the plugdev group rw permissions for 1209:5af0:

    ```
    $ lsusb | grep DFU
    Bus 001 Device 007: ID 1209:5af0 Generic OrangeCrab r0.2 DFU Bootloader v3.1-6-g62e92e2
    $ cat <<EOF | sudo tee /etc/udev/rules.d/99-OrangeCrab-DFU.rules
    # OrangeCrab DFU bootloader (hold down btn0 button while plugging in USB)
    ACTION=="add", SUBSYSTEM=="usb", \
     ATTRS{idVendor}=="1209", ATTRS{idProduct}=="5af0", GROUP="plugdev", MODE="664"
    EOF
    ```

   Also see the Debian wiki page for udev:
   - https://wiki.debian.org/udev

3. Unplug OrangeCrab, hold down the button, then plug it in again to trigger
   the new udev rule.

4. Try listing devices again:

    ```
    $ dfu-util --list 2>&1 | perl -ne 'print if $n++ > 6' | grep -v '05ac:8289'
    Deducing device DFU version from functional descriptor length
    Found DFU: [1209:5af0] ver=0101, devnum=9, cfg=1, intf=0, path="1-2", alt=1,\
    name="0x00100000 RISC-V Firmware", serial="UNKNOWN"
    Found DFU: [1209:5af0] ver=0101, devnum=9, cfg=1, intf=0, path="1-2", alt=0,\
    name="0x00080000 Bitstream", serial="UNKNOWN"
    ```

    So... it looks like there are two different flash regions? Something called
    `alt=1` associated with `0x00100000` and something called `alt=0`
    associated with `0x00080000`.

5. String search orangecrab-fpga Github repositories for variations on 0x100000
   and 0x80000 to see what they might mean...

   - [orangecrab-examples/riscv/blink/sections.ld](https://github.com/orangecrab-fpga/orangecrab-examples/blob/9006469bd5873228244a693d380d6f20e7398a7d/riscv/blink/sections.ld#L6-L11)
     Comments say, "RISCV code is stored in the SPI FLASH" and "0x80000 is the
     offset the bootloader jumps to"

   - [orangecrab-examples/riscv/button/sections.ld](https://github.com/orangecrab-fpga/orangecrab-examples/blob/9006469bd5873228244a693d380d6f20e7398a7d/riscv/button/sections.ld#L6-L11)
     Same comments as in blink/sections.ld

   - [orangecrab-examples/litex/combine.py](https://github.com/orangecrab-fpga/orangecrab-examples/blob/9006469bd5873228244a693d380d6f20e7398a7d/litex/combine.py#L10-L12)
     `flash_regions_final` dictionary specifies 0x00000000 as "Bootloader",
     0x00080000 as "SoC ECP5 Bitstream", and 0x00100000 as "Circuit PYthon"

   - [orangecrab-examples/litex/SoC-CircuitPython.py](https://github.com/orangecrab-fpga/orangecrab-examples/blob/9006469bd5873228244a693d380d6f20e7398a7d/litex/SoC-CircuitPython.py#L271)
     `...["FLASH_BOOT_ADDRESS"] = ... mem_map['spiflash'] + 0x00100000`

   - [orangecrab-examples/litex/README-CircuitPython-Example.md](https://github.com/orangecrab-fpga/orangecrab-examples/blob/9006469bd5873228244a693d380d6f20e7398a7d/litex/README-CircuitPython-Example.md#combine-soc-and-circuit-python-firmware-and-flash)
     The "Combine SoC and Circuit Python firmware and flash" section describes
     creating a binary with "our code" at 0x800000 and "CircuitPython riscv
     code at 0x100000 in FLASH after we've loaded it through the DFU
     bootloader."


## Discoveries

1. The
   [litex/README-CircuitPython-Example.md](https://github.com/orangecrab-fpga/orangecrab-examples/blob/main/litex/README-CircuitPython-Example.md)
   file from orangecrab-fpga/orangecrab-examples on Github walks through an
   example of building and running CircuitPython 5.2.0.

2. [Commit 929cea3](https://github.com/orangecrab-fpga/orangecrab-examples/commit/929cea3d7e4a538bcfd15ba487cd1dc8b165fee9)
   in the `prebuilt` branch of orangecrab-examples includes a
   [litex/combine.dfu](https://github.com/orangecrab-fpga/orangecrab-examples/blob/929cea3d7e4a538bcfd15ba487cd1dc8b165fee9/litex/combine.dfu)
   file that looks like it's be a prebuilt DFU image including CircuitPython.
   It's unclear to me if it was built for the 25F or 85F board.

<!-- raw combine.dfu
https://github.com/orangecrab-fpga/orangecrab-examples/raw/929cea3d7e4a538bcfd15ba487cd1dc8b165fee9/litex/combine.dfu
-->


## Logic Analyzer Wiring

This is how I've currently connected pins between my OrangeCrab and logic
analyzer:

| Logic 8 | OrangeCrab | Feather Spec |
| ------- | ---------- | ------------ |
|   | A0   | A0  |
|   | A1   | A1  |
|   | A2   | A2  |
|   | A3   | A3  |
|   | A4   | A4 / D24 |
|   | A5   | A5 / D25 |
|   | SCK  | SCK |
|   | MOSI | MO  |
|   | MISO | MI  |
| 0 | 0    | RX / D0 |
| 1 | 1    | TX / D1 |
| 2 | SDA  | SDA |
| 3 | SCL  | SCL |
| 4 | 5    | D5  |
| 5 | 6    | D6  |
| 6 | 9    | D9  |
| 7 | 10   | D10 |
|   | 11   | D1 |
|   | 12   | D1 |
|   | 13   | D1 |

Also see: https://learn.adafruit.com/adafruit-feather/feather-specification
