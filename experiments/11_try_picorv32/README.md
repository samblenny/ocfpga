<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 11 Try PicoRV32


## Goals:

1. **Build a PicoRV32 bitstream**: Translate a
   [PicoRV32](https://github.com/YosysHQ/picorv32) CPU from Verilog into an
   ECP5 bitstream with YosysHQ tools.

2. **Verilog and lpf for a pullup**: Write Verilog and .lpf files for a
   bitstream to produce observable output on an IO pin. Putting a pullup on the
   SDA pin would be great as I already have it wired to my logic analyzer.

3. **Verilog and lpf for low power**: Write Verilog and .lpf files for for a
   bitstream that gives a baseline low current configuration (DRAM in reset or
   room temperature refresh, no floating IO pins, low ECP5 clock speed). Try to
   measure difference against factory firmware with a thermal camera (temp
   above ambient) or USB power meter (mA).

4. **PicoRV32 bitstream ROM to change a pin**: Wire the CPU up to the LED or an
   IO pin and write code to modulate the output. Probably this will use object
   code baked into the bitstream as a ROM.

5. **PicoRV32 XIP from flash to change a pin**: Modify the previous experiment
   to use eXecute In Place (XIP) to run compiled C code from SPI flash.


## Results

*work in progress*

1. My initial attempt at building a PicoRV32 pretty much just worked, producing
   a bitstream file that looks like I could flash it to my OrangeCrab 85F. I
   didn't try to run this because it's very unlikely that the IO pins are
   configured reasonably.

   This stuff ran without any errors...

    ```console
    $ cd ~/code
    $ git clone https://github.com/YosysHQ/picorv32.git
    $ cd picorv32
    $ yosys -p "read_verilog picorv32.v; synth_ecp5 -json picorv32.json"
    $ nextpnr-ecp5 --json picorv32.json --textcfg picorv32_out.config --85k --package CSFBGA285
    $ ecppack --compress --freq 38.8 --input picorv32_out.config --bit picorv32.bit
    $ du -sh picorv32.bit
    312K	picorv32.bit
    ```

2. I made a big table of ECP5 IO banks, pin/ball names, schematic signal names,
   and pin functions to help me make sense of how pin constraints should be
   assigned. The CSV version of my table is in
   [oc-ecp5u-25f-85f-pinout.csv](oc-ecp5u-25f-85f-pinout.csv).

   I wrote a script, [gen_lpf.py](gen_lpf.py) to generate an lpf pin constraint
   file from the CSV file. The script includes rules to decide on 1.35V logic
   (DRAM IO banks) or 3.3V logic (the other IO banks). **The DRAM chip is a
   1.35V low voltage device, so setting the IO modes carefully is important.**

   The lpf pin constraint file is [pullup.lpf](pullup.lpf).

3.  For baseline current and heat dissipation measurements...

    Using a relatively inexpensive USB power meter whose calibration I'm not
    sure how much to trust (perhaps accurate to +/- 10 mA?), I measured the
    following:

    | bitstream/firmware          | V    | mA              |
    | --------------------------- | ---- | --------------- |
    | bootloader                  | 5.10 | 51 (avg, noisy) |
    | verilog pwm_rainbow example | 5.10 | 43 (stable-ish) |

    On the thermal camera, these measurements were pretty typical:

    | bitstream/firmware          | ECP5 °F | DRAM °F | Ambient °F |
    | --------------------------- | ------- | ------- | ---------- |
    | bootloader                  | 88.2    | 83.9    | 77.6       |
    | verilog pwm_rainbow example | 85.2    | 81.2    | 77.1       |

    The OrangeCrab r0.2.1 board seems to spread heat very well. Aside from the
    ECP5 and the voltage regulators, the rest of the board had an approximately
    uniform temperature. It seemed like most the heat was coming from the ECP5.

    The pwm_rainbow bitstream (from orangecrab-examples/verilog) ran at about
    8 mA less, on average, compared to the bootloader in DFU mode.

    Over all, this is better than I expected from reading orangecrab-hardware
    issue 19 (50-ish mA rather than 70-ish mA). But, still, idling at 50 mA is
    kind of a lot.


4. ...

5. ...


## Lab Notes

Contents:

- [Build a PicoRV32 bitstream](#Build-a-PicoRV32-bitstream)

- [Verilog and lpf for a pullup](#Verilog-and-lpf-for-a-pullup) (big pinout table)

- [Verilog and lpf for low power](#Verilog-and-lpf-for-low-current)

- [PicoRV32 bitstream ROM to change a pin](#PicoRV32-bitstream-ROM-to-change-a-pin)

- [PicoRV32 XIP from flash to change a pin](#PicoRV32-XIP-from-flash-to-change-a-pin)


### Build a PicoRV32 bitstream

1. Clone repo and check out
   [commit 336cfca](https://github.com/YosysHQ/picorv32/tree/336cfca6e5f1c08788348aadc46b3581b9a5d585)
   (current head of main on April 18, 2024)...

    ```console
    $ cd ~/code
    $ git clone https://github.com/YosysHQ/picorv32.git
    ...
    $ cd picorv32
    $ git checkout -b 2024-04-18 336cfca6e5f1c08788348aadc46b3581b9a5d585
    Switched to a new branch '2024-04-18'
    ```

2. Read about how to build PicoRV32...

   hmm... the main PicoRV32 readme doesn't appear to explain anything about
   this. It only mentions building RV32 toolchains. The implication is that if
   you've already got a Verilog `.v` file, maybe it should be trivially easy?

3. Try some wild-guess `yosys` and `nextpnr-ecp5` invocations inspired by the
   example invocations from `orangecrab-examples/verilog/*` Makefiles...

    ```console
    $ cd ~/code/picorv32
    $ yosys -p "read_verilog picorv32.v; synth_ecp5 -json picorv32.json"
    ...
    2.47. Printing statistics.

    === picorv32_wb ===

       Number of wires:               1442
       Number of wire bits:           5076
       Number of public wires:        1442
       Number of public wire bits:    5076
       Number of ports:                 24
       Number of port bits:            341
       Number of memories:               0
       Number of memory bits:            0
       Number of processes:              0
       Number of cells:               2393
         $scopeinfo                      1
         CCU2C                         177
         L6MUX21                        16
         LUT4                         1305
         PFUMX                         184
         TRELLIS_DPR16X4                32
         TRELLIS_FF                    678

    2.48. Executing CHECK pass (checking for obvious problems).
    Checking module picorv32_wb...
    Found and reported 0 problems.

    2.49. Executing JSON backend.

    End of script. Logfile hash: b285c5aad4, CPU: user 6.91s system 0.10s, MEM: 110.19 MB peak
    Yosys 0.40 (git sha1 a1bb0255d65, g++ 12.2.0-14 -fPIC -Os)
    Time spent: 18% 38x opt_expr (1 sec), 12% 11x techmap (1 sec), ...
    ```

   That seems good, I guess?

4. Now try place and route...

    ```console
    $ nextpnr-ecp5 --json picorv32.json --textcfg picorv32_out.config --85k --package CSFBGA285
    ...
    Info: Device utilisation:
    Info: 	          TRELLIS_IO:   341/  365    93%
    Info: 	                DCCA:     1/   56     1%
    Info: 	              DP16KD:     0/  208     0%
    Info: 	          MULT18X18D:     0/  156     0%
    Info: 	              ALU54B:     0/   78     0%
    Info: 	             EHXPLLL:     0/    4     0%
    Info: 	             EXTREFB:     0/    2     0%
    Info: 	                DCUA:     0/    2     0%
    Info: 	           PCSCLKDIV:     0/    2     0%
    Info: 	             IOLOGIC:     0/  224     0%
    Info: 	            SIOLOGIC:     0/  141     0%
    Info: 	                 GSR:     0/    1     0%
    Info: 	               JTAGG:     0/    1     0%
    Info: 	                OSCG:     0/    1     0%
    Info: 	               SEDGA:     0/    1     0%
    Info: 	                 DTR:     0/    1     0%
    Info: 	             USRMCLK:     0/    1     0%
    Info: 	             CLKDIVF:     0/    4     0%
    Info: 	           ECLKSYNCB:     0/   10     0%
    Info: 	             DLLDELD:     0/    8     0%
    Info: 	              DDRDLL:     0/    4     0%
    Info: 	             DQSBUFM:     0/   14     0%
    Info: 	     TRELLIS_ECLKBUF:     0/    8     0%
    Info: 	        ECLKBRIDGECS:     0/    2     0%
    Info: 	                DCSC:     0/    2     0%
    Info: 	          TRELLIS_FF:   678/83640     0%
    Info: 	        TRELLIS_COMB:  1899/83640     2%
    Info: 	        TRELLIS_RAMW:    32/10455     0%

    Info: Placed 0 cells based on constraints.
    ...
    Info: Max frequency for clock '$glbnet$wb_clk_i$TRELLIS_IO_IN': 91.80 MHz (PASS at 12.00 MHz)

    Info: Max delay <async>                                -> posedge $glbnet$wb_clk_i$TRELLIS_IO_IN: 9.23 ns
    Info: Max delay posedge $glbnet$wb_clk_i$TRELLIS_IO_IN -> <async>                               : 8.16 ns
    ```

   I think that worked? If I'm reading it right, the CPU design got
   synthesized, placed, and routed.

5. Now try making a bitstream...

    ```console
    $ ecppack --compress --freq 38.8 --input picorv32_out.config --bit picorv32.bit
    $ du -sh picorv32.bit
    312K	picorv32.bit
    ```

   Seems like that worked too? Hmm... spooky. Just kinda randomly trying stuff
   here. Why no errors?

   Anyhow, even if I were to try loading the bitstream, this configuration is
   probably useless because I didn't provide Verilog or a `.lpf` file
   specifying how to wire up the ECP5 IO pins. I also didn't do anything to
   specify how the CPU will load code or set its program counter after reset.
   Nor did I prepare any RV32 object code.


### Verilog and lpf for a pullup

6. I want to make a minimalist Verilog and lpf file example to build a
   bitstream that will put a pullup on the SDA pin. So, among other things, I
   need to understand `.lpf` constraint files for nextpnr...

   The orangecrab-examples repo includes a
   [verilog/orangecrab_r0.2.1.pcf](https://github.com/orangecrab-fpga/orangecrab-examples/blob/main/verilog/orangecrab_r0.2.1.pcf)
   `.pcf` file which sets up a bunch of constraints for nextpnr. Most of that
   file has to do with setting up differential IO pairs for the DRAM chip,
   which I totally don't care about.

   *Somewhat mysteriously, the orangecrab-examples ECP5 pin constraints are in
   a pcf file, which is the file format for Lattice iCE40 pin constraints. But,
   the syntax in the file is actually ECP5-style lpf. I initially didn't catch
   that distinction and was thinking that ECP5 also used pcf. Now, I've learned
   ECP5 uses lpf files for pin constraints.*

   In the YosysHQ/nextpnr repository,
   [docs/constraints.md](https://github.com/YosysHQ/nextpnr/blob/master/docs/constraints.md)
   explains a bit about how constraints work. On Lattice's ECP5 page, in the
   [Documentation](https://www.latticesemi.com/Products/FPGAandCPLD/ECP5#_11D625E1D2C7406C96A5312C93FF0CBD)
   section,
   [ECP5 and ECP5-5G sysIO Usage Guide](https://www.latticesemi.com/view_document?document_id=50464)
   (FPGA-TN-02032) explains what the different pin mode constants mean (drive
   strength, slew rate, termination, differential or not, etc).

7. Trying to understand how lpf files map between Verilog wire names and
   whatever sort of names are built into `nextpnr-ecp5`'s model of the ECP5 85F
   CSFBGA285 package...

   The Lattice ECP5 product page
   [Documentation section](https://www.latticesemi.com/Products/FPGAandCPLD/ECP5#_11D625E1D2C7406C96A5312C93FF0CBD)
   includes the
   "[ECP5U-25 Pinout ](https://www.latticesemi.com/view_document?document_id=50485)"
   and
   "[ECP5U-85 Pinout](https://www.latticesemi.com/view_document?document_id=50487)"
   CSV files with columns including:
   - "Pad" (values in: 0..670)
   - "Pin/Ball Function" (values like: GND, PL11A, ...)
   - "Bank" (values in: 0..8, 40)
   - "CSFBGA285" (values like: C12, B12, A12, ...)

   In both the 25F and 85F pinout CSV files, the "Bank", and "CSFBGA285"
   columns match up with the orangecrab-fpga/orangecrab-hardware
   [r0.2.1 schematic pdf](https://github.com/orangecrab-fpga/orangecrab-hardware/blob/main/hardware/orangecrab_r0.2.1/Production/OrangeCrab_r0.2.1_sch.pdf)
   labels on the "/FPGA/" sheet. Also, the "Dual Function" columns are mostly
   identical. But, only the "Pin/Ball Function" column of the 25F pinout CSV
   matches the labels in the schematic.

   So, I'm not sure about functional differences between the 25F and 85F. Maybe
   they act exactly the same even though the "Pin/Ball Function" labels for 25F
   are not the same as those for 85F. I need to read the ECP5 family data sheet
   to check on that.

   I went through both pinout CSV files and the r0.2.1 schematic to compile a
   table of all CSFBGA285 pins that were not GND, RESERVED, or VCC-something.

   Some notes:
   - `USER_BUTTON` has an external 1.35V pullup
   - Several pins are wired to `P1.35V` or `ECP5_VREF`
   - Many pins have external 3.3V pullups
   - A few pins are wired to `GND`, directly or through a pulldown

   What I take from that is, configuring IO pins for anything other than high
   impedance needs to be approached with caution.

   The orangecrab-examples/verilog/orangecrab_r0.2.1.pcf file (*yes, it's a .pcf
   file, but the syntax is actually that of an lpf file*) includes lines like,

   ```
   LOCATE COMP "clk48" SITE "A9";
   ```

   where the `SITE` strings, like `"A9"` match entries in the "CSFBGA285" ball
   name column. In that case, according to the schematic, `A9` is wired to the
   `OUT` pin of `OSC1`, which is a Kyocera KC2520B48.0000C10E00 50ppm, 48 MHz
   clock oscillator. So, I see that it makes sense to call it `clk48`. Also,
   from the table, `A9` has the "dual function" of `PCLKT1_0`.

   According to Lattice's
   [ECP5 and ECP5-5G sysCLOCK PLL/DLL Design and Usage Guide](https://www.latticesemi.com/view_document?document_id=50465)
   (page 16, section 8.3. Dedicated Clock Inputs), the ECP5 has various `PCLK`
   pins which can bring external clock signals into the "Primary clock network".
   So, I guess that's what must be going on with `A9` and `OSC`.

   Anyhow, this is my big table of pin/ball names and schematic signal names:

   | Bank | CSFBGA285 | r0.2.1 25F Schematic | 25F Func | Dual Func | 85F Func |
   | ---- | --------- | -------------------- | -------- | --------- | -------- |
   | 0 | A10 | NC | PT27B | PCLKC0_1 | PT63B |
   | 0 | A11 | NC | PT27A | PCLKT0_1 | PT63A |
   | 0 | **B10** | IO_5 (Feather) | PT29A | PCLKT0_0 | PT65A |
   | 0 | B11 | NC | PT4A |  | PT4A |
   | 0 | **C10** | IO_SDA (**Feather**) | PT29B | PCLKC0_0 | PT65B |
   | 0 | C11 | NC | PT4B |  | PT4B |
   | 1 | A8 | IO_11 (Feather) | PT35B | PCLKC1_0 | PT71B |
   | 1 | **A9** | REF_CLK (wired to **OSC1 OUT**) | PT35A | PCLKT1_0 | PT71A |
   | 1 | B8 | IO_10 (Feather) | PT67A |  | PT121A |
   | 1 | B9 | IO_6 (Feather) | PT33A | PCLKT1_1 | PT69A |
   | 1 | C8 | IO_9 (Feather) | PT67B |  | PT121B |
   | 1 | **C9** | IO_SCL (**Feather**) | PT33B | PCLKC1_1 | PT69B |
   | 2 | A2 | RAM_A14 | PR20C | GR_PCLK2_0 | PR41C |
   | 2 | A3 | RAM_A3 | PR20A | GR_PCLK2_1 | PR41A |
   | 2 | A4 | RAM_A4 | PR11B |  | PR20B |
   | 2 | A6 | RAM_BA2 | PR11A |  | PR20A |
   | 2 | A7 | RAM_A10 | PR8B |  | PR17B |
   | 2 | B1 | RAM_A8 | PR23B | PCLKC2_1 | PR44B |
   | 2 | B2 | RAM_A7 | PR20B |  | PR41B |
   | 2 | **B4** | wired to ECP5_VREF | PR14C | **VREF1_2** | PR35C |
   | 2 | B6 | RAM_A12 | PR8A |  | PR17A |
   | 2 | B7 | RAM_BA1 | PR2B |  | PR11B |
   | 2 | C1 | RAM_A13 | PR23C | PCLKT2_0 | PR44C |
   | 2 | C2 | RAM_A11 | PR17B |  | PR38B |
   | 2 | C3 | RAM_A6 | PR14D |  | PR35D |
   | 2 | C4 | RAM_A0 | PR14B |  | PR35B |
   | 2 | C6 | wired to P1.35V | PR5B |  | PR14B |
   | 2 | C7 | RAM_A15 | PR2A |  | PR11A |
   | 2 | D1 | RAM_A9 | PR23D | PCLKC2_0 | PR44D |
   | 2 | D2 | RAM_A1 | PR23A | PCLKT2_1 | PR44A |
   | 2 | D3 | RAM_A2 | PR17A |  | PR38A |
   | 2 | D4 | RAM_A5 | PR14A |  | PR35A |
   | 2 | D6 | RAM_BA0 | PR5A |  | PR14A |
   | 3 | F1 | ADC_CTRL1 | PR35C |  | PR56C |
   | 3 | F2 | ADC_MUX2 | PR32A |  | PR53A |
   | 3 | F3 | ADC_MUX1 | PR26D | PCLKC3_0 | PR47D |
   | 3 | F4 | ADC_MUX0 | PR26C | PCLKT3_0 | PR47C |
   | 3 | G1 | ADC_CTRL0 | PR32B |  | PR53B |
   | 3 | G3 | ADC_SENSE_LO | PR29B |  | PR50B |
   | 3 | G4 | IO_A4 (Feather) | PR26B | PCLKC3_1 | PR47B |
   | 3 | H1 | ADC_MUX3 | PR35D |  | PR56D |
   | 3 | H2 | IO_12 (Feather) | PR29D |  | PR50D |
   | 3 | H3 | ADC_SENSE_HI | PR29A | GR_PCLK3_0 | PR50A |
   | 3 | H4 | IO_A3 (Feather) | PR26A | PCLKT3_1 | PR47A |
   | 3 | J1 | SD0_DAT0 (microSD; 3.3V pullup) | PR35B | VREF1_3 | PR56B |
   | 3 | J2 | IO_13 (Feather) | PR35A |  | PR56A |
   | 3 | **J3** | LED_B (**LED**) | PR29C | GR_PCLK3_1 | PR50C |
   | 3 | K1 | SD0_CLK (microSD) | PR41D |  | PR86D |
   | 3 | K2 | SD0_CMD (microSD; 3.3V pullup) | PR44A |  | PR89A |
   | 3 | K3 | SD0_DAT1 (microSD; 3.3V pullup) | PR41C |  | PR86C |
   | 3 | **K4** | LED_R (**LED**) | PR38A |  | PR83A |
   | 3 | L1 | SD0_CD (microSD; 3.3V pullup) | PR44B |  | PR89B |
   | 3 | L3 | SD0_DAT2 (microSD; 3.3V pullup) | PR41B |  | PR86B |
   | 3 | L4 | IO_A0 (Feather) | PR38B |  | PR83B |
   | 3 | M1 | SD0_DAT3 (microSD; pullup???) | PR47C | LRC_GPLL0T_IN | PR92C |
   | 3 | **M2** | USB_D- (**USB**) | PR44C |  | PR89C |
   | 3 | **M3** | LED_G (**LED**) | PR41A |  | PR86A |
   | 3 | **N1** | USB_D+ (**USB**) | PR47D | LRC_GPLL0C_IN | PR92D |
   | 3 | **N2** | USB_PULLUP (**USB**) | PR44D |  | PR89D |
   | 3 | N3 | IO_A1 (Feather) | PR38D |  | PR83D |
   | 3 | N4 | IO_A2 (Feather) | PR38C |  | PR83C |
   | 6 | C18 | RAM_D13 | PL26B | PCLKC6_1 | PL47B |
   | 6 | D17 | wired to P1.35V | PL26A | PCLKT6_1 | PL47A |
   | 6 | **D18** | RAM_CKE (**DRAM Power**) | PL26C | PCLKT6_0 | PL47C |
   | 6 | F15 | RAM_D11 | PL29C | GR_PCLK6_1 | PL50C |
   | 6 | F16 | RAM_D9 | PL29B |  | PL50B |
   | 6 | F17 | RAM_D8 | PL29A | GR_PCLK6_0 | PL50A |
   | 6 | F18 | RAM_D15 | PL26D | PCLKC6_0 | PL47D |
   | 6 | G15 | RAM_D10 | PL35A |  | PL56A |
   | 6 | G16 | RAM_LDM | PL29D |  | PL50D |
   | 6 | G18 | RAM_LDQS+ | PL32A |  | PL53A |
   | 6 | **H15** | wired to ECP5_VREF | PL35B | **VREF1_6** | PL56B |
   | 6 | H16 | RAM_D14 | PL35C |  | PL56C |
   | 6 | H17 | RAM_LDQS- | PL32B |  | PL53B |
   | 6 | H18 | NC | PL38D |  | PL83D |
   | 6 | J16 | RAM_D12 | PL35D |  | PL56D |
   | 6 | **J17** | USER_BUTTON (1.35V pullup) | PL38C |  | PL83C |
   | 6 | J18 | RAM_CK+ | PL41A |  | PL86A |
   | 6 | K15 | wired to P1.35V | PL41D |  | PL86D |
   | 6 | K16 | wired to P1.35V | PL41C |  | PL86C |
   | 6 | K17 | wired to P1.35V | PL44A |  | PL89A |
   | 6 | K18 | RAM_CK- | PL41B |  | PL86B |
   | 6 | L15 | wired to GND | PL44C |  | PL89C |
   | 6 | L16 | wired to GND | PL44D |  | PL89D |
   | 6 | **L18** | RAM_RESET# (**DRAM Power**) | PL44B |  | PL89B |
   | 6 | M16 | EXT_PLL+ | PL47C | LLC_GPLL0T_IN | PL92C |
   | 6 | M17 | EXT_PLL- | PL47D | LLC_GPLL0C_IN | PL92D |
   | 7 | A12 | RAM_CS# | PL5A |  | PL14A |
   | 7 | A13 | RAM_D7 | PL14B |  | PL35B |
   | 7 | A15 | RAM_D4 | PL14D |  | PL35D |
   | 7 | A16 | RAM_UDQS- | PL20B |  | PL41B |
   | 7 | A17 | RAM_D6 | PL23A | PCLKT7_1 | PL44A |
   | 7 | B12 | RAM_WE# | PL2B |  | PL11B |
   | 7 | B13 | RAM_D5 | PL14A |  | PL35A |
   | 7 | B15 | RAM_UDQS+ | PL20A | GR_PCLK7_1 | PL41A |
   | 7 | B17 | RAM_D2 | PL23B | PCLKC7_1 | PL44B |
   | 7 | B18 | wired to P1.35V | PL23C | PCLKT7_0 | PL44C |
   | 7 | C12 | RAM_RAS# | PL2A |  | PL11A |
   | 7 | **C13** | RAM_ODT (**DRAM Power**) | PL8B |  | PL17B |
   | 7 | **C15** | wired to ECP5_VREF | PL14C | **VREF1_7** | PL35C |
   | 7 | C16 | RAM_D3 | PL20C | GR_PCLK7_0 | PL41C |
   | 7 | C17 | RAM_D0 | PL23D | PCLKC7_0 | PL44D |
   | 7 | D13 | RAM_CAS# | PL8A |  | PL17A |
   | 7 | D15 | RAM_D1 | PL17A |  | PL38A |
   | 7 | D16 | RAM_UDM | PL17B |  | PL38B |
   | 8 | **M18** | IO_1 (**Feather TX**) | PB6B | D4/MOSI2/IO4 | PB6B |
   | 8 | N15 | IO_MISO (Feather) | PB4A | D7/IO7 | PB4A |
   | 8 | N16 | IO_MOSI (Feather) | PB4B | D6/IO6 | PB4B |
   | 8 | **N17** | IO_0 (**Feather RX**) | PB6A | D5/MISO2/IO5 | PB6A |
   | 8 | N18 | QSPI_D3 | PB9A | D3/IO3 | PB9A |
   | 8 | R16 | NC | PB18A | WRITEN | PB18A |
   | 8 | R17 | IO_SCK (Feather) | PB13A | SN/CSN | PB13A |
   | 8 | R18 | QSPI_D2 | PB9B | D2/IO2 | PB9B |
   | 8 | T14 | wired to P3.3V (**Config**) | CFG_1 |  | CFG_1 |
   | 8 | T15 | FPGA_RESET (see V17; 3.3V pullup) | PROGRAMN |  | PROGRAMN |
   | 8 | T17 | IO_A5 (Feather) | PB13B | CS1N | PB13B |
   | 8 | T18 | SPI_CONFIG_MISO | PB11A | D1/MISO/IO1 | PB11A |
   | 8 | U14 | wired to GND (**Config**) | CFG_0 |  | CFG_0 |
   | 8 | U15 | NC | DONE |  | DONE |
   | 8 | U16 | SPI_CONFIG_SCK (3.3V pullup) | CCLK | MCLK/SCK | CCLK |
   | 8 | U17 | SPI_CONFIG_SS (3.3V pullup) | PB15A | HOLDN/DI/BUSY/... | PB15A |
   | 8 | U18 | SPI_CONFIG_MOSI | PB11B | D0/MOSI/IO0 | PB11B |
   | 8 | V15 | wired to GND (**Config**) | CFG_2 |  | CFG_2 |
   | 8 | V16 | NC | INITN |  | INITN |
   | 8 | V17 | FPGA_RESET (see T15; 3.3V pullup) | PB15B | DOUT/CSON | PB15B |
   | 40 | T13 | JTAG_TDI | TDI |  | TDI |
   | 40 | U13 | JTAG_TCK (pulldown) | TCK |  | TCK |
   | 40 | V13 | JTAG_TMS | TMS |  | TMS |
   | 40 | V14 | JTAG_TDO | TDO |  | TDO |


8. Writing lpf and Verilog files to put a pullup on `IO_SDA`...

   I wrote a script, [gen_lpf.py](gen_lpf.py) to generate an lpf pin constraint
   file that puts the pins on the DRAM banks (2, 6, and 7) in 1.35V mode and
   puts the other pins in 3.3V modes (mostly pulldowns for Feather IO pins, a
   pullup on SDA, and pullmode=none for the other stuff).

   The lpf file is [pullup.lpf](pullup.lpf).

   **TODO: finish this**


### Verilog and lpf for low current

10. **TODO: finish this**

    If I'm reading
    [orangecrab-hardware issue 19](https://github.com/orangecrab-fpga/orangecrab-hardware/issues/19),
    right, **gateware configuration can reduce OrangeCrab's current draw by
    by about 120 mA!** Most of that has to do with termination resistors. If I
    understand correctly, about 110 mA of current draw was probably eliminated
    by hardware changes between r0.2 and r0.2.1. But, about another 120 mA on
    top of that can be eliminated with gateware changes.

    This is the table I made while trying to follow the mA and mW references in
    that issue thread (the two "hw" lines appeared to be hardware changes):

    |                                    |        |         |
    | ---------------------------------- | ------ | ------- |
    | baseline: stock r0.2 board         | 300 mA | 1500 mW |
    | remove VTT resistors  (hw)         | -50 mA | -250 mW |
    | turn off ODT                       | -50 mA | -250 mW |
    | "disable the virtual VCC/GND" (hw) | -60 mA | -300 mW |
    |                                    |        |         |
    | subtotal                           | 140 mA |  700 mW |
    |                                    |        |         |
    | DIFFRESISTOR=OFF, TERMINATION=OFF  | -68 mA | -340 mW |
    |                                    |        |         |
    | total (r0.2.1 + tuned gateware?)   |  72 mA |  360 mW |

    In the
    [MT41K64M16TW_107:J datasheet](https://media-www.micron.com/-/media/client/global/documents/products/data-sheet/dram/ddr3/1gb_1_35v_ddr3l.pdf)
    (the DRAM chip on OrangeCrab 85F), the chart on page 42 suggests that the
    lowest current operating modes might be Reset (14 mA?), something called
    "Precharge power-down current;Slow exit" (12 mA), and something called
    "Room temperature self refresh" (8 mA). Without including a DRAM controller
    core in my gateware (to send control commands to the DRAM chip), I'm
    assuming the easiest way to cut DRAM current draw would be to add a
    constraint with a weak pulldown resistor on the `RAM_RESET#` pin (Bank 6:
    PL44B, L18). It's also possible that one of the other pins can activate the
    "room temperature self refresh" thing. I should probably read the data
    sheet more carefully.

    Using a relatively inexpensive USB power meter whose calibration I'm not
    sure how much to trust (perhaps accurate to +/- 10 mA?), I measured the
    following:

    | bitstream/firmware          | V    | mA              |
    | --------------------------- | ---- | --------------- |
    | bootloader                  | 5.10 | 51 (avg, noisy) |
    | verilog pwm_rainbow example | 5.10 | 43 (stable-ish) |

    On the thermal camera, these measurements were pretty typical:

    | bitstream/firmware          | ECP5 °F | DRAM °F | Ambient °F |
    | --------------------------- | ------- | ------- | ---------- |
    | bootloader                  | 88.2    | 83.9    | 77.6       |
    | verilog pwm_rainbow example | 85.2    | 81.2    | 77.1       |

    The OrangeCrab r0.2.1 board seems to spread heat very well. Aside from the
    ECP5 and the voltage regulators, the rest of the board had an approximately
    uniform temperature. It seemed like most the heat was coming from the ECP5.

    The pwm_rainbow bitstream (from orangecrab-examples/verilog) ran at about
    8 mA less, on average, compared to the bootloader in DFU mode.

    Over all, this is better than I expected from reading orangecrab-hardware
    issue 19 (50-ish mA rather than 70-ish mA). But, still, idling at 50 mA is
    kind of a lot.


### PicoRV32 bitstream ROM to change a pin

20. **TODO**


### PicoRV32 XIP from flash to change a pin

30. **TODO**


### PicoRV32 C code to XIP ROM to change a pin

40. **TODO**
