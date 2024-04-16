<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 05 Try Riscv Examples

Goals:

1. Build ECP5 85F DFU binaries for the riscv example projects in my fork of
   orangecrab-fpga/orangecrab-examples:
   [samblenny/orangecrab-examples](https://github.com/samblenny/orangecrab-examples)

2. Flash and run the binaries


## Results

1. The `riscv/button` example after installing toolchain and modifying Makefile:

   https://github.com/samblenny/ocfpga/assets/68084116/d7068e28-e92d-47cc-9af7-04bac62ded20

   If the player above doesn't work, the video of the LED changing as I press
   the btn0 button is at [05_button_example.mp4](05_button_example.mp4).

2. The `riscv/blink` example:

   https://github.com/samblenny/ocfpga/assets/68084116/72ea94d6-2579-4271-b628-7db14578e07b

   If the player above doesn't work, there's a video of the LED blinking cyan
   at [05_blink_example.mp4](05_blink_example.mp4).

3. Copies of my DFU binaries for `riscv/blink` and `riscv/button` are in
   [./dfu_prebuilt/](dfu_prebuilt), along with a copy of the license (MIT)
   from the orangecrab-examples repo. For details, see
   [dfu_prebuilt/README.md](dfu_prebuilt/README.md).


## Plan

1. Install a gcc toolchain for riscv64-unknown-elf. It needs to include
   libraries that will work with `-march=rv32i -mabi=ilp32`

2. Modify Makefiles to include support for 85F:
   - `dfu-suffix` may be hardcoded for 25F (1209:5bf2). 85F is `1209:5af0`
   - Check if `dfu-util` is invoked without specifying `-d vendor:product` or
     without `--alt <n>`

3. Check ECP5 datasheet, foboot VexRiscv litex config, and `sections.ld` files
   to see if the `sram` and `spiflash` addresses that were written for 25F are
   still okay for 85F.

4. For Makefiles or litex .py files that are hardcoded for the ECP5 25F, add an
   option to use the 85F. These are some places that may need changes:

    ```
    $ grep -ir '25[kf]' riscv litex verilog amaranth
    litex/SoC-CircuitPython.py:        device = kwargs.get("device", "25F")
    litex/SoC-CircuitPython.py:    parser.add_argument("--device", default="25F",
    litex/SoC-CircuitPython.py:                        help="ECP5 device (default=25F)")
    verilog/blink/Makefile:# `25F` or `85F`
    verilog/blink/Makefile:DENSITY=25F
    verilog/blink/Makefile:	NEXTPNR_DENSITY:=--25k
    verilog/pwm_rainbow/Makefile:# `25F` or `85F`
    verilog/pwm_rainbow/Makefile:DENSITY=25F
    verilog/pwm_rainbow/Makefile:	NEXTPNR_DENSITY:=--25k
    verilog/blink_reset/Makefile:# `25F` or `85F`
    verilog/blink_reset/Makefile:DENSITY=25F
    verilog/blink_reset/Makefile:	NEXTPNR_DENSITY:=--25k
    verilog/pll/Makefile:# `25F` or `85F`
    verilog/pll/Makefile:DENSITY=25F
    verilog/pll/Makefile:	NEXTPNR_DENSITY:=--25k
    verilog/blink_reset_module/Makefile:# `25F` or `85F`
    verilog/blink_reset_module/Makefile:DENSITY=25F
    verilog/blink_reset_module/Makefile:	NEXTPNR_DENSITY:=--25k
    verilog/usb_acm_device/Makefile:# `25F` or `85F`
    verilog/usb_acm_device/Makefile:DENSITY=25F
    verilog/usb_acm_device/Makefile:	NEXTPNR_DENSITY:=--25k
    ```

   See also: orangecrab-examples
   [issue 21 "85F compatiblity"](https://github.com/orangecrab-fpga/orangecrab-examples/issues/21)

5. Edit (or add) README files explaining how to build for 85F instead of 25F.


## Lab Notes

1. Fork [orangecrab-fpga/orangecrab-examples](https://github.com/orangecrab-fpga/orangecrab-examples)
   as [samblenny/orangecrab-examples](https://github.com/samblenny/orangecrab-examples)

2. Clone samblenny/orangecrab-examples

3. Create `add-85F-support` branch (`git checkout -b add-85F-support`)

4. Modify orangecrab-examples/50-orangecrab.rules to include udev rules for
   both the OrangeCrab 85F and the OrangeCrab 25F.

5. Download a toolchain...

   One of the orangecrab-examples README files mentions downloading a RISC-V
   toolchain from SiFive. But, when I followed that link, it had a bunch of
   marketing stuff for IDEs and SDKs with links to a login-protected portal. I
   don't want to mess with that. So...

   Instead, download a gcc toolchain (includes 32-bit Newlib) from the
   [RISC-V Embedded stable release compilers](https://www.embecosm.com/resources/tool-chain-downloads/#riscv-stable)
   section of Embecosm's
   [Tool Chain Downloads](https://www.embecosm.com/resources/tool-chain-downloads/)
   page (thanks to \@tannewt for the tip about these toolchains). I picked the
   version with GCC 13.2.0, Binutils 2.41, GDB 13.2, and Newlib 4.2.0 for
   Ubuntu 22.04 (amd64). The gzipped tarball is 1.2GB.

    ```
    $ cd ~/bin
    $ wget https://buildbot.embecosm.com/job/riscv32-gcc-ubuntu2204-release/10/artifact/riscv32-embecosm-ubuntu2204-gcc13.2.0.tar.gz
    ```

6. Install toolchain by unpacking the toolchain archive, adding its `bin`
   directory to my `$PATH`, then restarting my shell:

   [CAUTION: this is meant for Debian or Ubuntu, don't do this on macOS]

    ```
    $ cd ~/bin
    $ tar xf riscv32-embecosm-ubuntu2204-gcc13.2.0.tar.gz
    $ echo '# Add riscv gcc toolchain to path' >> ~/.bashrc
    $ echo 'export PATH=$PATH:$HOME/bin/riscv32-embecosm-ubuntu2204-gcc13.2.0/bin' >> ~/.bashrc
    ```

7. Exit shell, restart shell, then check that compiler is usable:

    ```
    $ which riscv32-unknown-elf-gcc
    /home/sam/bin/riscv32-embecosm-ubuntu2204-gcc13.2.0/bin/riscv32-unknown-elf-gcc
    $ riscv32-unknown-elf-gcc --version | head -n 1
    riscv32-unknown-elf-gcc ('riscv32-embecosm-ubuntu2204-gcc13.2.0') 13.2.0
    ```

8. Attempt to build the `orangecrab-examples/riscv/button` example:

   First, check what the Makefile thinks the cross compiler is called:
    ```
    $ cd orangecrab-examples/riscv/button/
    $ grep riscv..-unknown-elf Makefile
    CROSS=riscv64-unknown-elf-
    ```

   That's not right for the Embecosm toolchain, so change it:
    ```
    $ sed -i 's/riscv64-unknown-elf-/riscv32-unknown-elf-/' Makefile
    ```

   Also add new rules so `dfu-util` will work with the 85F product ID. First
   do `vim Makefile`, then add this stuff (be sure to use real tabs):

    ```
    # ---- 85F Target ----
    dfu_85F: button_85F.dfu
        dfu-util -d 1209:5af0 --alt 0 -D button_85F.dfu | perl -ne 'print if $$n++>5'

    button_85F.dfu: blink_fw.bin
        cp blink_fw.bin button_85F.dfu
        dfu-suffix -v 1209 -p 5af0 -a button_85F.dfu 2>&1 | perl -ne 'print if $$n++>5'

    # ---- Clean ----

    clean:
        rm -f blink_fw.bin blink_fw.elf blink_fw.dfu button_85F.dfu
    ```

   Make the `button_85F.dfu` target:
    ```
    $ make button_85F.dfu
    riscv32-unknown-elf-gcc  -march=rv32i -mabi=ilp32 \
        -Wl,-Bstatic,-T,sections.ld,--strip-debug -ffreestanding -nostdlib \
        -I. -o blink_fw.elf start.s main.c
    start.s: Assembler messages:
    start.s:62: Error: unrecognized opcode `csrw mtvec,a0', extension `zicsr' required
    start.s:87: Error: unrecognized opcode `csrw mie,a0', extension `zicsr' required
    make: *** [Makefile:12: blink_fw.elf] Error 1
    ```

   That failed because the gcc naming for the `-march=rv32i` architecture
   target changed since the example's Makefile was written 4 years ago. For
   gcc13, it needs to use `-march=rv32i_zicsr`. So, change that argument:
    ```
    $ sed -i 's/-march=rv32i/-march=rv32i_zicsr/' Makefile
    ```

   Try it again using the `dfu_85F` target to include the DFU download:
    ```
    $ make dfu_85F
    riscv32-unknown-elf-gcc  -march=rv32i_zicsr -mabi=ilp32 \
        -Wl,-Bstatic,-T,sections.ld,--strip-debug -ffreestanding -nostdlib \
        -I. -o blink_fw.elf start.s main.c
    riscv32-unknown-elf-objcopy -O binary blink_fw.elf blink_fw.bin
    cp blink_fw.bin button_85F.dfu
    dfu-suffix -v 1209 -p 5af0 -a button_85F.dfu 2>&1 | perl -ne 'print if $n++>5'
    Suffix successfully added to file
    dfu-util -d 1209:5af0 --alt 0 -D button_85F.dfu | perl -ne 'print if $n++>5'

    Deducing device DFU version from functional descriptor length
    Opening DFU capable USB device...
    Device ID 1209:5af0
    Device DFU version 0101
    Claiming USB DFU Interface...
    Setting Alternate Interface #0 ...
    Determining device status...
    DFU state(2) = dfuIDLE, status(0) = No error condition is present
    DFU mode device DFU version 0101
    Device returned transfer size 4096
    Copying data from PC to DFU device
    Download	[=========================] 100%         1488 bytes
    Download done.
    DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
    DFU state(8) = dfuMANIFEST-WAIT-RESET, status(0) = No error condition is present
    error resetting after download (LIBUSB_ERROR_NO_DEVICE)
    Resetting USB to switch back to runtime mode
    Done!
    ```

   That works! Now the OrangeCrab boots with the RGB LED red. Pressing the
   button cycles through blue, green, then back to red.

   There's a video up in the [Results](#results) section. If the player doesn't
   work, there's a copy at [05_button_example.mp4](05_button_example.mp4).

9. Attempt to build the `orangecrab-examples/riscv/blink` example:

   First, fix the Makefile similarly to the changes above for `riscv/button`:

    ```diff
    $ git diff
    diff --git a/riscv/blink/Makefile b/riscv/blink/Makefile
    index 838e484..4c724e9 100644
    --- a/riscv/blink/Makefile
    +++ b/riscv/blink/Makefile
    @@ -1,5 +1,5 @@

    -CROSS=riscv64-unknown-elf-
    +CROSS=riscv32-unknown-elf-
     CFLAGS=

     all: blink_fw.dfu
    @@ -8,8 +8,9 @@ all: blink_fw.dfu
     dfu: blink_fw.dfu
            dfu-util -D blink_fw.dfu

    +# gcc13 needs -march=rv32i_zicsr (the old way was just -march=rv32i)
     blink_fw.elf: start.s main.c
    -       $(CROSS)gcc $(CFLAGS) -march=rv32i -mabi=ilp32 -Wl,-Bstatic,-T,sections.ld,--strip-debug -ffreestanding -nostdlib -I. -o blink_fw.elf start.s main.c
    +       $(CROSS)gcc $(CFLAGS) -march=rv32i_zicsr -mabi=ilp32 -Wl,-Bstatic,-T,sections.ld,--strip-debug -ffreestanding -nostdlib -I. -o blink_fw.elf start.s main.c

     blink_fw.hex: blink_fw.elf
            $(CROSS)objcopy -O verilog blink_fw.elf blink_fw.hex
    @@ -21,9 +22,17 @@ blink_fw.dfu: blink_fw.bin
            cp blink_fw.bin blink_fw.dfu
            dfu-suffix -v 1209 -p 5bf0 -a blink_fw.dfu

    +# ---- 85F Target ----
    +dfu_85F: blink_85F.dfu
    +       dfu-util -d 1209:5af0 --alt 0 -D blink_85F.dfu | perl -ne 'print if $$n++>5'
    +
    +blink_85F.dfu: blink_fw.bin
    +       cp blink_fw.bin blink_85F.dfu
    +       dfu-suffix -v 1209 -p 5af0 -a blink_85F.dfu 2>&1 | perl -ne 'print if $$n++>5'
    +
     # ---- Clean ----

     clean:
    -       rm -f blink_fw.bin blink_fw.elf blink_fw.dfu
    +       rm -f blink_fw.bin blink_fw.elf blink_fw.dfu blink_85F.dfu

    -.PHONY: all
    \ No newline at end of file
    +.PHONY: all
    ```

    Build the DFU binary:
    ```
    $ make blink_85F.dfu
    riscv32-unknown-elf-gcc  -march=rv32i_zicsr -mabi=ilp32 \
        -Wl,-Bstatic,-T,sections.ld,--strip-debug -ffreestanding -nostdlib \
        -I. -o blink_fw.elf start.s main.c
    riscv32-unknown-elf-objcopy -O binary blink_fw.elf blink_fw.bin
    cp blink_fw.bin blink_85F.dfu
    dfu-suffix -v 1209 -p 5af0 -a blink_85F.dfu 2>&1 | perl -ne 'print if $n++>5'
    Suffix successfully added to file
    ```

    Connect the OrangeCrab 85F in DFU mode, then load the binary with:
    ```
    $ make dfu_85F
    dfu-util -d 1209:5af0 --alt 0 -D blink_85F.dfu | perl -ne 'print if $n++>5'

    Deducing device DFU version from functional descriptor length
    Opening DFU capable USB device...
    Device ID 1209:5af0
    Device DFU version 0101
    Claiming USB DFU Interface...
    Setting Alternate Interface #0 ...
    Determining device status...
    DFU state(2) = dfuIDLE, status(0) = No error condition is present
    DFU mode device DFU version 0101
    Device returned transfer size 4096
    Copying data from PC to DFU device
    Download	[=========================] 100%         1136 bytes
    Download done.
    DFU state(7) = dfuMANIFEST, status(0) = No error condition is present
    DFU state(8) = dfuMANIFEST-WAIT-RESET, status(0) = No error condition is present
    Resetting USB to switch back to runtime mode
    Done!
    ```

   It works. LED blinks bright cyan-ish (maybe turquoise?).

   There's a video up in the [Results](#results) section. If the player doesn't
   work, there's a copy at [05_blink_example.mp4](05_blink_example.mp4).
