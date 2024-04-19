<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 11 Try PicoRV32


## Goals:

1. Translate a [PicoRV32](https://github.com/YosysHQ/picorv32) CPU from
   Verilog into an ECP5 bitstream with YosysHQ tools.

2. Write Verilog to wire the CPU up to an observable output: blink the LED,
   flip a GPIO pin, export a register to JTAG, or anything I can get working.

3. Write a C program, compile it, and run it on the PicoRV32. Anything I can
   get working to produce observable output would be fine.


## Results

*work in progress*

1. ...


## Lab Notes

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

   That seems good, I guess? Now try place and route...

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

   Now try making a bitstream...

    ```console
    $ ecppack --compress --freq 38.8 --input picorv32_out.config --bit picorv32.bit
    $ du -sh picorv32.bit
    312K	picorv32.bit
    ```

   Seems like that worked too? Hmm... spooky. Just kinda randomly trying stuff
   here. Why no errors?

   Anyhow, even if I were to try loading the bitstream, this configuration is
   probably useless because I didn't provide Verilog or a `.pcf` file
   specifying how to wire up the ECP5 IO pins. I also didn't do anything to
   specify how the CPU will load code or set its program counter after reset.
   Nor did I prepare any RV32 object code.

4. Thinking about `.pcf` constraint files for nextpnr...

   The orangecrab-examples repo includes a
   [verilog/orangecrab_r0.2.1.pcf](https://github.com/orangecrab-fpga/orangecrab-examples/blob/main/verilog/orangecrab_r0.2.1.pcf)
   `.pcf` file which sets up a bunch of constraints for nextpnr. Most of that
   file has to do with setting up differential IO pairs for the DRAM chip,
   which I totally don't care about. If possible, I would like to figure out
   how to hold the thing in reset, or otherwise reduce its current consumption.

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
   "Precharge power-down current;Slow exit" (12 mA), and something called "Room
   temperature self refresh" (8 mA). Without including a DRAM controller core
   in my gateware (to send control commands to the DRAM chip), I'm assuming the
   easiest way to cut DRAM current draw would be to add a constraint with a
   weak pulldown resistor on the `RAM_RESET#` pin (Bank 6: PL44B, L18). It's
   also possible that one of the other pins can activate the "room temperature
   self refresh" thing. I should probably read the data sheet more carefully.

   For understanding how to write `.pcf` files...

   In the YosysHQ/nextpnr repository,
   [docs/constraints.md](https://github.com/YosysHQ/nextpnr/blob/master/docs/constraints.md)
   explains a bit about how constraints work. On Lattice's ECP5 page, in the
   [Documentation](https://www.latticesemi.com/Products/FPGAandCPLD/ECP5#_11D625E1D2C7406C96A5312C93FF0CBD)
   section,
   [ECP5 and ECP5-5G sysIO Usage Guide](https://www.latticesemi.com/view_document?document_id=50464)
   (FPGA-TN-02032) explains what the different pin mode constants mean (drive
   strength, slew rate, termination, differential or not, etc).

5. ...

**TODO: write a pcf file, figure out how to wire PicoRV32 data bus to GPIO pin**
