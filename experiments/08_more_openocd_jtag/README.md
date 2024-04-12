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

4. Figure out how to make the ECP5 logically unplug itself from USB any time
   that an OpenOCD JTAG operation might halt the clock for the OrangeCrab
   bootloader's USB stack.

   Based on how the OrangeCrab's RGB LED color usually freezes while loading
   code over JTAG (using ecpprog), I'm guessing that JTAG may be halting the
   ECP5 (or bootloader SoC?) clock without tristating the IO pins. If that
   happens to the USB pins, it might be responsible for JTAG programming
   seeming to hide the bootloader's DFU device from `lsusb` and `dfu-util`.
   (`dmesg` can still see it, and everything works again if I reboot Debian.)


## Context

The point of this stuff is to level up my workflow for loading and running
gateware and firmware. Setting up an ergonomic, reliable, and reasonably speedy
way to iterate on SoC and firmware revisions will save me a lot of time and
trouble later on.

The OrangeCrab 85F has 16 MB of flash, but the factory DFU bootloader is
limited to accessing two slots of 512 KB each. Also, the OrangeCrab's DFU
bootloader doesn't provide much in the way of debugging or logging interfaces
to help troubleshoot boot problems.

Using JTAG should, hopefully, provide access to the whole flash chip and let me
observe more of what's going on inside the ECP5.


## Results

*work in progress*


## Lab Notes

1. Spent a bunch of time reading through OpenOCD docs to learn about options
   for FTDI adapters, JTAG, boards, and so on:
   - https://openocd.org/doc/html/Debug-Adapter-Configuration.html
   - https://openocd.org/doc/html/Reset-Configuration.html

   This is what I came up with for a first attempt at an `openocd.cfg` file:

    ```tcl
    # openocd.cfg for Tigard JTAG probe (FT2232H) + OrangeCrab 85F (ECP5)
    source [find interface/ftdi/tigard.cfg]
    source [find fpga/lattice_ecp5.cfg]

    # speed unit is kHz
    adapter speed 500
    ftdi tdo_sample_edge falling

    # OrangeCrab JTAG is only 5-pin (no reset pins)
    reset_config none
    ```

2. Playing around with `openocd` telnet shell...

   First, start the server:

    ```console
    $ openocd
    Open On-Chip Debugger 0.12.0
    Licensed under GNU GPL v2
    For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
    Info : auto-selecting first available session transport "jtag". To override use 'transport select <transport>'.
    none separate

    Info : Listening on port 6666 for tcl connections
    Info : Listening on port 4444 for telnet connections
    Info : clock speed 500 kHz
    Info : JTAG tap: ecp5.tap tap/device found: 0x41113043 (mfg: 0x021 (Lattice Semi.), part: 0x1113, ver: 0x4)
    Warn : gdb services need one or more targets defined
    ```

   Then connect over telnet in a second terminal:

    ```
    $ telnet localhost 4444
    Trying ::1...
    Connection failed: Connection refused
    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    Open On-Chip Debugger
    >
    ```

   List available commands:

    ```
    > help
    ...[a big long list]
    ```

   Highlights of the help list:
   - `adapter speed <kHz>`
   - `exit`: end telnet session
   - `flash banks`: show table of flash bank info
     (see https://openocd.org/doc/html/Flash-Commands.html )
   - `flash init`: init flash devices
   - `flash list`: list of details about flash banks
   - `gdb_flash_program (enable|disable)`: enable/disable flash program
   - `irscan [tap_name ...]`: do an Instruction Register scan
   - `jtag arp_init`: validate JTAG scan chain against TAPs in config
   - `jtag init`: init scan chain
   - `jtag names`: print list of JTAG tap names
   - `scan_chain`: print scan chain config
   - `target create ...`: configure target CPU
     (see https://openocd.org/doc/html/CPU-Configuration.html )
   - `shutdown`: shut down the openocd server

   Try some commands:

    ```
    > adapter speed
    adapter speed: 500 kHz

    > flash banks
    > flash list
    > jtag names
    ecp5.tap
    > jtag arp_init
    JTAG tap: ecp5.tap tap/device found: 0x41113043 (mfg: 0x021 \
        (Lattice Semi.), part: 0x1113, ver: 0x4)
    > lattice read_status
    invalid command name "lattice"
    > reset init
    invalid command name "reset"
    > target create ECP5 testee
    The 'target create' command must be used before 'init'.
    > target create ECP5 testee -chain-position ECP5.tap
    The 'target create' command must be used before 'init'.
    ```

   Hmm... aside from adapter speed, that's all kinda mysterious.

   These pages from the OpenOCD html docs look relevant for figuring out how to
   set up flash banks and enable the `lattice` fpga driver which has flash
   related commands:
   - [12 Flash Commands](https://openocd.org/doc/html/CPU-Configuration.html)
   - [13 Flash Programming](https://openocd.org/doc/html/Flash-Programming.html)
   - [14 PLD/FPGA Commands](https://openocd.org/doc/html/PLD_002fFPGA-Commands.html)

3. Reading around a bit, I discovered that, on Github,
   [YosysHQ/prjtrellis/examples](https://github.com/YosysHQ/prjtrellis/tree/master/examples)
   has Makefile examples using `ecppack` to make `.svf` files which are then
   fed to `openocd`.

   Perhaps the trick to the flash programming is learning about SVF files?

   The source for [YosysHQ/prjtrellis/libtrellis/tools/ecppack.cpp](https://github.com/YosysHQ/prjtrellis/blob/master/libtrellis/tools/ecppack.cpp)
   has a bunch of SVF string-generating stuff down at the bottom of the file.
   Many of the string fragments correspond to things I've seen in the OpenOCD
   docs about low-level JTAG commands. I'm guessing that `ecppack` can make a
   series of JTAG commands that will talk to the ECP5, telling it how to
   write a bitstream to flash.

   I've also been seeing [openFPGAloader](https://github.com/trabucayre/openFPGALoader)
   mentioned in several places.


### Trying openFPGALoader

4. What if I try using openfpgaloader?

   Install:

    ```console
    $ sudo apt install openfpgaloader
    $ openFPGALoader --Version
    openFPGALoader v0.10.0
    ```

   Attempt to detect supported devices:

    ```
    $ openFPGALoader --scan-usb
    found 6 USB device
    Bus device vid:pid       probe type      manufacturer serial               product
    001 005    0x0403:0x6010 FTDI2232        SecuringHardware.com TG110bb4             Tigard V1.1
    $
    $ openFPGALoader --list-cables | grep tigard
    tigard                   0x0403:6010
    $
    $ openFPGALoader --list-fpga | grep 'LFE5U-[28]5'
    0x41111043  lattice       ECP5            LFE5U-25
    0x41113043  lattice       ECP5            LFE5U-85
    $
    $ openFPGALoader --cable tigard --freq 1M --detect
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    index 0:
        idcode 0x1113043
        manufacturer lattice
        family ECP5
        model  LFE5UM-85
        irlength 8
    ```

   🎉 This is looking pretty encouraging so far!

   I tried programming blinky and made a big mess with many failed attempts,
   including some stuff that trashed the bootloader again. Finally I figured
   out how to flash the bootloader. The key non-obvious missing link was that
   I [needed to](https://github.com/trabucayre/openFPGALoader/issues/45#issuecomment-978108298)
   include `--file-type raw`:

    ```console
    $ cd ~/code/ocfpga/experiments/04_try_prebuilt_firmware/prebuilt/
    $ ls
    blink_fw.dfu     combine.dfu                          orangecrab-reboot-85F.bit
    combine_85F.dfu  foboot-v3.1-orangecrab-r0.2-85F.bit  orangecrab-test-85F.bit
    $ openFPGALoader \
        --cable tigard \
        --freq 1M \
        --write-flash \
        --file-type raw \
        foboot-v3.1-orangecrab-r0.2-85F.bit
    write to flash
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Open file DONE
    Parse file DONE
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    00000000 00000000 00000000 00
    Erasing: [==================================================] 100.00%
    Done
    Writing: [==================================================] 100.00%
    Done
    Refresh: DONE
    ```

   Now attempt to flash blinky at offset 0x8000:

    ```console
    $ cd ~/code/ocfpga/experiments/05_try_riscv_examples/dfu_prebuilt/
    $ ls
    blink_85F.dfu  button_85F.dfu  LICENSE_RISCV_EXAMPLES  README.md
    $ openFPGALoader \
        --cable tigard \
        --freq 1M \
        --write-flash \
        --file-type raw \
        -o 0x8000 \
        blink_85F.dfu
    write to flash
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Open file DONE
    Parse file DONE
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    00008000 00000000 00000000 00
    Erasing: [==================================================] 100.00%
    Done
    Writing: [==================================================] 100.00%
    Done
    Refresh: FAIL
    displayReadReg
        Config Target Selection : 0
        Std PreAmble
        SPIm Fail1
        CRC ERR
        EXEC Error
    Error: Failed to program FPGA: std::exception
    ```

   That fails miserably. Same result for assorted variations on JTAG clock
   frequency, file-type, offset, TDO rising/falling edge, and so on. It's also
   interesting that after this fails, the bootloader gets broken. But, if I
   just repeat the `openFPGALoader ...` invocation above, it un-bricks the
   bootloader, no problem. So, perhaps this is erasing or overwriting part of
   the bootloader, in addition to whatever else may be going on.

   Anyhow, this is all so mysterious. I have no idea what's going on. But, I
   like the way that `openFPGALoader` seems to do a good job of detecting what
   it's talking to and that it seems careful about validating things, checking
   file formats, and so on.

5. Maybe the errors will go away if I try building `openFPGALoader` v0.12.1
   from source? Reading the change logs, there seem to be many bug-fixes for
   things involving SPI flash on Lattice devices.

   Build openFPGALoader v0.12.1 and make a script in `~/bin` to start it:

    ```console
    $ cd ~/bin
    $ wget https://github.com/trabucayre/openFPGALoader/archive/refs/tags/v0.12.1.tar.gz
    $ mv v0.12.1.tar.gz openFPGALoader-v0.12.1.tar.gz
    $ tar xf openFPGALoader-v0.12.1.tar.gz
    $ cd openFPGALoader-0.12.1
    $ sudo apt install libftdi1-dev
    $ cmake .
     ...
    $ make
     ...
    $ ./openFPGALoader --Version
    openFPGALoader v0.12.1
    $ cat <<EOF > ~/bin/openFPGALoader-v0.12.1.sh
    #!/bin/sh
    \$HOME/bin/openFPGALoader-0.12.1/openFPGALoader \$@
    EOF
    $ chmod +x ~/bin/openFPGALoader-v0.12.1.sh
    $ openFPGALoader-v0.12.1.sh --Version
    openFPGALoader v0.12.1
    ```

   Try flashing blinky with the new build:

    ```console
    $ cd ~/code/ocfpga/experiments/05_try_riscv_examples/dfu_prebuilt/
    $ openFPGALoader-v0.12.1.sh \
        --cable tigard \
        --freq 1M \
        --write-flash \
        --file-type raw \
        -o 0x8000 \
        blink_85F.dfu
    empty
    write to flash
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Open file DONE
    Parse file DONE
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    00008000 00000000 00000000 00
    Erasing: [==================================================] 100.00%
    Done
    Writing: [==================================================] 100.00%
    Done
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    Skip resetting device
    Refresh: FAIL
    displayReadReg
        Config Target Selection : 0
        Std PreAmble
        SPIm Fail1
        BSE Error Code
            CRC ERR
        EXEC Error
    Error: Failed to program FPGA: std::exception
    ```

   Well... that didn't help. It's basically the same aside for some fancier
   formatting of error messages.

   An idea for debugging this... Try dumping the first 1M of flash in bricked
   and non-bricked state, then take a `diff` of the `hexdump -C` of both files.
   Maybe also compare those to programming the bootloader and blinky with
   `ecpprog`. The point is to see if `openFPGALoader` might be erasing extra
   blocks. Like, what if writing blinky causes the bootloader to be erased?

   Example of dumping flash with bricked bootloader:

    ```console
    $ openFPGALoader-v0.12.1.sh -c tigard --freq 1M --dump-flash --file-size 1000000 out-brick.bin
    empty
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    dump flash (May take time)
    Open dump file DONE
    Read flash : [==================================================] 100.00%
    Done
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    Skip resetting device
    Refresh: FAIL
    displayReadReg
        Config Target Selection : 0
        Std PreAmble
        SPIm Fail1
        BSE Error Code
            CRC ERR
        EXEC Error
    $ hexdump -C out-brick.bin > out-brick.bin.hex
    ```

   I tried diffing the bricked and un-bricked bootloader + blinky setup. The
   diff was pretty small. Not much larger than the the blinky object code.

   [*time passes while I contemplate the hexdump diff*]

   Oh wow. I've been making the same dumb mistake over and over again for the
   past couple hours without noticing... `-o 0x8000` is very different from
   `-o 0x80000`.

   This is what I've been doing:

    ```console
    $ history | grep '0x8000 '
     2068  openFPGALoader --cable tigard --freq 1M -f -o 0x8000 blink_85F.dfu
     2069  openFPGALoader --cable tigard --freq 100k -f -o 0x8000 blink_85F.dfu
     2073  openFPGALoader --cable tigard --freq 100k -f -o 0x8000 -v blink_85F.dfu
     2099  openFPGALoader --cable tigard --freq 1M -f --file-type raw -o 0x8000 blink_85F.dfu
     2100  openFPGALoader --cable tigard --freq 1M -f -o 0x8000 blink_85F.dfu
     2101  openFPGALoader --cable tigard --freq 10k -f --file-type raw -o 0x8000 blink_85F.dfu
     2102  openFPGALoader --cable tigard --freq 10k -f -o 0x8000 blink_85F.dfu
     2105  openFPGALoader --cable tigard --freq 10k -f -o 0x8000 blink_85F.dfu
     2106  openFPGALoader --cable tigard --freq 1M -f -o 0x8000 blink_85F.dfu
     2107  openFPGALoader --cable tigard --freq 10k -f --file-type dfu -o 0x8000 blink_85F.dfu
    ```

   That's definitely overwriting the bootloader bitstream. So, the CRC error
   was complaining about a corrupted bitstream, not about verifying the flash.

   Try flashing blinky again, but this time with four zeros after the eight...

    ```console
    $ cd ~/code/ocfpga/experiments/05_try_riscv_examples/dfu_prebuilt/
    $ openFPGALoader --cable tigard --freq 1M --write-flash -o 0x80000 blink_85F.dfu
    write to flash
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Open file DONE
    Parse file DONE
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    00080000 00000000 00000000 00
    Erasing: [==================================================] 100.00%
    Done
    Writing: [==================================================] 100.00%
    Done
    Refresh: DONE
    ```

   It works!

   This is what I need.
