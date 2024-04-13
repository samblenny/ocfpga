# 08 More OpenOCD JTAG

Programming OrangeCrab over JTAG using `ecpprog` is fast when it works, but
it seems a bit unreliable. In particular, I want to see if programming flash
with OpenOCD can make the reset behavior more predictable.


## Goals

1. Configure OpenOCD to run Tigard interface at faster JTAG clock speed.

2. Figure out how to read and write flash using `openocd` or `openFPGALoader`.

3. If possible, find a way to display ECP5 status register in human-readable
   format. I want more information about what's going on with the bootloader
   when bitstreams and rv32 code don't run as expected.

4. [**Update**: *never mind... I thought the USB device implementation was
   causing trouble somehow, but the real problem was a bad USB cable. Wish I
   would have thought to check that earlier. Oh well.*]

   ~~Figure out how to make the ECP5 logically unplug itself from USB any time
   that an OpenOCD JTAG operation might halt the clock for the OrangeCrab
   bootloader's USB stack.~~

   ~~Based on how the OrangeCrab's RGB LED color freezes when I begin flashing
   code over JTAG, I'm guessing that JTAG programming leaves the ECP5 IO pin
   drivers in whatever mode they were set for prior to stopping the ECP5's
   clock. Hypothetically, since the pins seem to have output drivers enabled
   rather than going into high-impedance mode (HIGHZ), the USB data pins could
   be frozen just like the LED pins. In that case, the stuck pins might confuse
   Debian's USB host stack (or individual drivers). That could be why JTAG
   programming seems to hide the bootloader's DFU device from `lsusb` and
   `dfu-util`. (`dmesg` can still see it, and everything works again if I
   reboot Debian.)~~


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

I started off looking only at `openocd`, but then I found posts recommending
`openFPGALoader`, so I tried it too. Turns out that `openFPGALoader` is really
nice. I particularly like the ECP5 status register parser thing (shows
bitstream CRC errors, etc).

1. **Set JTAG clock speed to run faster than 100 kHz**:

   This `openocd.cfg` config works well for poking around in `openocd`'s telnet
   shell (`adapter speed 500` sets 500 kHz JTAG clock):

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

   This works well for running `openFPGALoader` at 1 MHz (`--freq 1M`):

    ```console
    $ cd ~/code/ocfpga/experiments/05_try_riscv_examples/dfu_prebuilt/
    $ openFPGALoader --cable tigard --freq 1M -f -o 0x80000 blink_85F.dfu
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

2. **Read and Write flash with openocd or openFPGALoader**:

   openFPGALoader can write and read arbitrary regions of flash...

   First write and verify the bootloader at the default offset (0x00):

    ```console
    $ cd ~/code/ocfpga/experiments/04_try_prebuilt_firmware/prebuilt/
    $ openFPGALoader -c tigard --freq 1M -f --file-type raw --verify \
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
    Verifying write (May take time)
    Read flash : [==================================================] 100.00%
    Done
    Refresh: DONE
    ```

   Then read it back and compare sha1 digests:

    ```console
    $ du --bytes foboot-v3.1-orangecrab-r0.2-85F.bit
    415247	foboot-v3.1-orangecrab-r0.2-85F.bit
    $ openFPGALoader -c tigard --freq 1M --dump-flash --file-size 415247 bootloader.bin
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    dump flash (May take time)
    Open dump file DONE
    Read flash : [==================================================] 100.00%
    Done
    Refresh: DONE
    $ shasum bootloader.bin foboot-v3.1-orangecrab-r0.2-85F.bit
    79eba51e1f4f9d92f99d0a5907ac01d44924c84a  bootloader.bin
    79eba51e1f4f9d92f99d0a5907ac01d44924c84a  foboot-v3.1-orangecrab-r0.2-85F.bit
    ```

   Now do the same thing with RISC-V object code at offset 0x80000 (512 KB):

    ```console
    $ cd ~/code/ocfpga/experiments/05_try_riscv_examples/dfu_prebuilt/
    $ openFPGALoader -c tigard --freq 1M -f --file-type raw --verify -o 0x80000 blink_85F.dfu
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
    Verifying write (May take time)
    Read flash : [==================================================] 100.00%
    Done
    Refresh: DONE
    $ # The LED is blinking now!
    $ du --bytes blink_85F.dfu
    1152	blink_85F.dfu
    $ openFPGALoader -c tigard --freq 1M --dump-flash -o 0x80000 --file-size 1152 blink.bin
    Jtag frequency : requested 1.00MHz   -> real 1.00MHz
    Enable configuration: DONE
    SRAM erase: DONE
    Detected: Winbond W25Q128 256 sectors size: 128Mb
    dump flash (May take time)
    Open dump file DONE
    Read flash : [==================================================] 100.00%
    Done
    Refresh: DONE
    $ shasum blink.bin blink_85F.dfu
    8336eafec73479325d8d38e0420bd97c6af2f161  blink.bin
    8336eafec73479325d8d38e0420bd97c6af2f161  blink_85F.dfu
    ```

3. **Read ECP5 status register**:

   `openFPGALoader` does this well when it writes to flash. If there is
   an error, it shows strings corresponding to error bits as described in
   Lattice's
   [ECP5 and ECP5-5G sysCONFIG User Guide](https://www.latticesemi.com/Products/FPGAandCPLD/ECP5#_11D625E1D2C7406C96A5312C93FF0CBD)
   pdf (see section "4.2. Device Status Register").

   For example, it showed me these errors when I bricked the bootloader by
   flashing blinky firmware at 32 KB (0x8000) instead of 512 KB (0x80000):

    ```
    Refresh: FAIL
    displayReadReg
        Config Target Selection : 0
        Std PreAmble
        SPIm Fail1
        CRC ERR
        EXEC Error
    Error: Failed to program FPGA: std::exception
    ```

   I think this is telling me that, when the ECP5 reset after flashing a
   blinky in the wrong spot, it detected a CRC error when attempting to read
   the bootloader bitstream from the external SPI flash chip.

   Basically, that's what I was hoping for: more indication of what might be
   going wrong when bitstream or firmware loading fails.

4. **Put ECP5 IO pins in HIGHZ during JTAG reprogramming**:

   [**Update**: *There's no need for this. The problem was a bad USB cable.
   But, it is interesting to know how to send boundary scan commands.*]

   I don't see any obvious path to make this happen with `openFPGALoader`
   on its own, but perhaps I can use `openocd` to put to set JTAG boundary scan
   for HIGHZ mode, then follow up with `openFPGALoader`.

   OpenOCD lets you write TCL code to send arbitrary JTAG commands. From
   reading about [JTAG boundary scan](https://en.wikipedia.org/wiki/JTAG) on
   wikipedia and some other assorted explain-jtag things I found, it sounds
   like I need to shift the `HIGHZ` bit pattern into the ECP5's "instruction
   register". The bit patterns are device-specific, but you can look up the
   right values to use in BSDL model files. Lattice has BSDL models for various
   ECP5 device + package combinations on the ECP5 web page's
   [downloads section](https://www.latticesemi.com/Products/FPGAandCPLD/ECP5#_11D625E1D2C7406C96A5312C93FF0CBD).

   According to the orangecrab-fpga/orangecrab-hardware Github repo's
   [hardware/orangecrab-r0.2.1/FPGA.sh ](https://github.com/orangecrab-fpga/orangecrab-hardware/blob/main/hardware/orangecrab_r0.2.1/FPGA.sch#L45)
   schematic file, the OrangeCrab 85F appears to use a `LFE5U-85F-8MG285`,
   where the 285 at the end indicates the BGA package type. Of the four 85F
   BSDL model files on the Lattice downloads page, it looks like the correct
   one would be "[BSDL] LFE5U85F CSFBGA285" (file name
   `BSDLLFE5U85FCSFBGA285.bsm`). In that model file, the `HIGHZ` bit pattern
   for the instruction register is listed as `00011000` (0b00011000 = 24).

   This seems to work for sending an irscan command without starting the full
   `openocd` server:

    ```console
    $ cd ~/code/ocfpga/experiments/08_more_openocd_jtag
    $ openocd -f openocd.cfg -c 'init; irscan ecp5.tap 24 -endstate DRPAUSE; exit'
    ...
    Info : clock speed 100 kHz
    Info : JTAG tap: ecp5.tap tap/device found: 0x41113043 (mfg: 0x021 \
        (Lattice Semi.), part: 0x1113, ver: 0x4)
    Warn : gdb services need one or more targets defined
    ```

   [**Update**: *the problem was a bad USB cable*]

   ~~When I did that `openocd` invocation while observing `watch lsusb` (2s
   updating of `lsusb`), the DFU device disappeared from the `lsusb` list and
   the RGB LED changed to dim white (maybe powered by an internal pullup?).~~

   ~~When I tried flashing a riscv example with `openFPGALoader`, it worked fine.
   But, there was no improvement to my ability to get the DFU device to show
   back up. For that to happen, I still had to shut down (not reboot) my host
   PC, then boot back into Debian. It seems that perhaps powering down my PC is
   necessary to reset some low-level hardware thing.~~~

   ~~I'm going to set this aside for now. I think I should just proceed with
   using JTAG and stop worrying about the factory bootloader. It seems to be
   unreliable, and JTAG is more convenient anyway. Perhaps I'll revisit this
   issue once I have a SoC working with a debug UART and an RV32 core.~~


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

    ```console
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

    ```console
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
        -f \
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
        -f \
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
        -f \
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
    $ openFPGALoader --cable tigard --freq 1M -f -o 0x80000 blink_85F.dfu
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


### How to put ECP5 IO pins in HIGHZ mode?

6. OpenOCD lets you write TCL code to send arbitrary JTAG commands. From
   reading about [JTAG boundary scan](https://en.wikipedia.org/wiki/JTAG) on
   wikipedia and some other assorted explain-jtag things I found, it sounds
   like I need to shift the `HIGHZ` bit pattern into the ECP5's "instruction
   register". The bit patterns are device-specific, but you can look up the
   right values to use in BSDL model files. Lattice has BSDL models for various
   ECP5 device + package combinations on the ECP5 web page's
   [downloads section](https://www.latticesemi.com/Products/FPGAandCPLD/ECP5#_11D625E1D2C7406C96A5312C93FF0CBD).

   According to the orangecrab-fpga/orangecrab-hardware Github repo's
   [hardware/orangecrab-r0.2.1/FPGA.sh ](https://github.com/orangecrab-fpga/orangecrab-hardware/blob/main/hardware/orangecrab_r0.2.1/FPGA.sch#L45)
   schematic file, the OrangeCrab 85F appears to use a `LFE5U-85F-8MG285`,
   where the 285 at the end indicates the BGA package type. Of the four 85F
   BSDL model files on the Lattice downloads page, it looks like the correct
   one would be "[BSDL] LFE5U85F CSFBGA285" (file name
   `BSDLLFE5U85FCSFBGA285.bsm`). In that model file, the `HIGHZ` bit pattern
   for the instruction register is listed as `00011000` (0b00011000 = 24).

   Based on that, I'm guessing `irscan ecp5.tap 24` may be the magic `openocd`
   incantation to invoke HIGHZ mode. So, I guess I'll just try it...

   First start the `openocd` server:
    ```console
    $ cd ~/code/ocfpga/experiments/08_more_openocd_jtag
    $ ls
    openocd.cfg  README.md
    $ openocd
    ...
    Info : Listening on port 4444 for telnet connections
    Info : clock speed 100 kHz
    Info : JTAG tap: ecp5.tap tap/device found: 0x41113043 (mfg: 0x021 \
        (Lattice Semi.), part: 0x1113, ver: 0x4)
    ...
    ```

   Then connect with telnet in a second terminal window and send the irscan:

    ```console
    $ telnet localhost 4444
    Trying ::1...
    Connection failed: Connection refused
    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    Open On-Chip Debugger
    > irscan ecp5.tap 24 -endstate DRPAUSE
    ```

   That clearly did something... the RGB LED doesn't go out, but it turned from
   red (was running riscv/button example) to a much dimmer white-ish. Maybe the
   LED is being powered by internal pullups?

   So, what happens if I reboot the Debian host PC to get a fresh un-glitched
   USB stack, boot the OrangeCrab in DFU mode, then watch the output of `lsusb`
   as I send the irscan for HIGHZ? ...

   [*rebooting*]

   The reboot (`sudo reboot`) didn't work, I can't see the DFU device in
   `lsusb`.

   [*shutting down, then powering back up*]

   Now I can see the DFU device with `watch lsusb`. Trying `openocd` without
   starting the telnet server:

    ```console
    $ cd ~/code/ocfpga/experiments/08_more_openocd_jtag
    $ openocd -f openocd.cfg -c 'init; irscan ecp5.tap 24 -endstate DRPAUSE; exit'
    ...
    Info : clock speed 100 kHz
    Info : JTAG tap: ecp5.tap tap/device found: 0x41113043 (mfg: 0x021 \
        (Lattice Semi.), part: 0x1113, ver: 0x4)
    Warn : gdb services need one or more targets defined
    ```

   After running that, the LED went dim white-ish, and the DFU device
   disappeared from `watch lsusb`, as if I had unplugged it. Now I will try
   flashing some code and rebooting into DFU mode...

   [*flashes riscv/button example with openFPGALoader, then rests to DFU mode*]

   Hmm... that's not working. I can see `dmesg` lines like
   `... usb 1-1: Product: OrangeCrab r0.2 DFU Bootloader v3.1-6-g62e92e2` if
   I plug in the board *without* holding down the button for DFU mode. But,
   there is no DFU device in the `lsusb` output. The weird thing is, if I plug
   in the OrangeCrab while holding the button, nothing shows up in `dmesg`
   about plugging in a USB device at all. Like, zero new lines after the
   disconnect message from unplugging the board after I'd booted it in non-DFU
   mode.

7. [**Update**: *the problem was a bad USB cable*]

   When I tried running `watch lsusb` and fiddling with the USB cable, I
   noticed the DFU device briefly appearing then disappearing. I could make it
   stay for longer by putting pressure on the cable. When I tried a different
   USB cable, the DFU device started showing up reliably, even right after JTAG
   flash programming.

   So, I take back what I said about the bootloader. It seems fine, but my USB
   cable sure wasn't. Power was okay, but one or more of the other wires had an
   intermittent fault. That's what I get for using an old cable, I guess.

   So, being able to send boundary scan commands with `openocd` is interesting,
   but not necessary. I should be able to just use `openFPGALoader` to flash
   new code and mostly ignore the bootloader. Using JTAG to program flash is
   pretty fast, and it doesn't require me to awkwardly plug and unplug the
   cable. So, I think using `openFPGALoader` will be good enough.
