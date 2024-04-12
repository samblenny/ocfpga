# 08 More OpenOCD JTAG

Programming OrangeCrab over JTAG using `ecpprog` is fast when it works, but
it seems a bit unreliable. In particular, I want to see if programming flash
with OpenOCD can make the reset behavior more predictable.


## Goals

1. Configure OpenOCD to run Tigard interface at faster JTAG clock speed.

2. Figure out how to read and write flash using `openocd`.

3. If possible, find a way to display ECP5 status register in human-readable
   format. I want more information about what's going on with the bootloader
   when bitstreams and rv32 code don't run as expected.

4. If possible, find a way to display any ECP5 fuses or other non-volatile
   configuration that control how code is loaded and run after reset.

   In particular, I want to know if there is an ECP5 mechanism that tries to
   load and run a primary bitstream, then fails over to a secondary bitstream
   if the first one has an error. (that might explain some of the weirdness
   I've been seeing.)

5. Figure out how to make the ECP5 logically unplug itself from USB any time
   that an OpenOCD JTAG operation might halt the clock for the OrangeCrab
   bootloader's USB stack.

   Based on how the OrangeCrab's RGB LED color usually freezes while loading
   code over JTAG (using ecpprog), I'm guessing that JTAG may be halting the
   ECP5 (or bootloader SoC?) clock without tristating the IO pins. If that
   happens to the USB pins, it might be responsible for JTAG programming
   seeming to hide the bootloader's DFU device from `lsusb` and `dfu-util`.
   (`dmesg` can still see it, and everything works again if I reboot Debian.)


## Results

*work in progress*


## Lab Notes

1. ...
