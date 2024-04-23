#!/usr/bin/python3
# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
import csv
import re
"""
Parse CSV file of OrangeCrab 85F pins to generate an lpf pin constraint file

=== DANGER! DANGER! DANGER! ==================================================
==                                                                          ==
==  The DRAM chip is a 1.35V low voltage device, while the ECP5 IO drivers  ==
==  can be configured for a range of voltages and modes. The absolute max   == 
==  rating for the DRAM chip IO pins is 1.975V. Feather IO pins need 3.3V.  ==
==  Sending 3.3V on a RAM_* pin would probably kill the DRAM chip. So we    ==
==  need to be very careful about configuring DRAM vs. non-DRAM pins!       ==
==                                                                          ==
==============================================================================

It might seem obvious to just use the orangecrab r0.2.1 pcf file, but I want
to understand how nextpnr ECP5 lpf constraint files work. Also, I want to
reduce my OrangeCrab's idle power dissipation. In the factory configuration,
the r0.2.1 85F only gets mildly toasty (I checked with the thermal camera). It
seems well within the bounds of being safe, but it still puts out substantial
heat. Running it on a battery might be impractical without first tuning for
better efficiency. Also, I'm not trying to run Linux or anything like that, so
I don't need so much RAM.

Anyhow, the main thing I want to do for now is just establish a safe baseline
configuration that avoids damaging the DRAM chip. The main difference here,
compared to the orangecrab-examples constraint file, is that I want to
configure the RAM pins as single-ended 1.35V inputs (rather than 1.35V
differential).

Later on, I will look at putting the DRAM chip in low power mode and turning
off the ECP5's differential driver circuitry.
""" 


class Pin:
    # Bookkeeping dictionary to avoid duplicate names
    names_seen = {}

    # IOBUF mode flags
    HIGHZ_33 = "PULLMODE=NONE IO_TYPE=LVCMOS33"
    HIGHZ_135 = "PULLMODE=NONE IO_TYPE=SSTL135_I"
    PULLDN_33 = "PULLMODE=DOWN IO_TYPE=LVCMOS33"
    PULLUP_33 = "PULLMODE=UP IO_TYPE=LVCMOS33"

    # VREF inputs wired to ECP5_VREF (0.675V) for DRAM differential IO
    ECP5_VREF = ('B4', 'H15', 'C15')

    # Regular inputs wired to P1.35V for DRAM differential IO
    P135V = ('C6', 'D17', 'K15', 'K16', 'K17', 'B18')

    # DRAM double-check list of 'RAM_*' IO pins
    RAM_IO = ('A2', 'A3', 'A4', 'A6', 'A7', 'B1', 'B2', 'B6', 'B7', 'C1', 'C2',
        'C3', 'C4', 'C7', 'D1', 'D2', 'D3', 'D4', 'D6', 'C18', 'F15', 'F16',
        'F17', 'F18', 'G15', 'G16', 'G18', 'H16', 'H17', 'J16', 'J18', 'K18',
        'A12', 'A13', 'A15', 'A16', 'A17', 'B12', 'B13', 'B15', 'B17', 'C12',
        'C16', 'C17', 'D13', 'D15', 'D16')

    # DRAM double-check list of 'RAM_*' power-related pins
    RAM_POWER = (
        'D18',     # RAM_CKE
        'L18',     # RAM_RESET#
        'C13')     # RAM_ODT

    # Everything on ECP5 IO pin banks 2, 6, and 7 should be 1.35V. Most of
    # them are DRAM IO pins, but there are also some VREF and GND references
    # along with the USER_BUTTON pin.
    DRAM_BANK = ('2', '6', '7')

    def __init__(self, bank, ball, sig):
        """Model the description of an ECP5 pin and its schematic name."""
        self.bank = bank
        self.ball = ball
        self.sig = sig

        # Clean name from CSV schematic column format to good verilog name
        sig = re.sub(r' *\([^)]*\)', '', sig)  # remove (notes)
        sig = re.sub(r'\+', '_pos', sig)       # '+' -> '_pos' 
        sig = re.sub(r'-', '_neg', sig)        # '-' -> '_neg' 
        sig = re.sub(r'#', '_inv', sig)        # '#' -> '_inv' 
        sig = re.sub(r'\.', '', sig)           # '.' -> '' 
        sig = sig.lower()                      # lowercase
        if bank in Pin.DRAM_BANK:
            sig = re.sub(r'wired to ', 'ram_', sig)
        else:
            sig = re.sub(r'wired to ', '', sig)
        self.clean_sig = sig

        # Dis-ambiguate duplicates (e.g. unnamed pins wired to P1.35V)
        if self.clean_sig in ('ram_gnd', 'ram_p135v', 'ram_ecp5_vref'):
            self.clean_sig += f"__{self.ball}"
        if self.clean_sig in Pin.names_seen:
            raise Exception("duplicate name: {self.clean_sig}, {self.sig}")
        Pin.names_seen[self.clean_sig] = 1

        # Decide what type of pin this is
        if re.match(r'user_button', sig):  # Button has 1.35V ext pullup
            self.iobuf = Pin.HIGHZ_135
        elif re.match(r'ram_', sig):       # DRAM 1.35V !
            self.iobuf = Pin.HIGHZ_135
        elif re.match(r'p135v', sig):      # DRAM 1.35V !
            self.iobuf = Pin.HIGHZ_135
        elif re.match(r'ecp5_vref', sig):  # DRAM 1.35V !
            self.iobuf = Pin.HIGHZ_135
        elif re.match(r'ext_pll', sig):    # EXT_PLL* pins are in DRAM bank
            self.iobuf = Pin.HIGHZ_135
        elif re.match(r'io_0', sig):       # RX pin is special, no pulldown
            self.iobuf = Pin.HIGHZ_33
        elif re.match(r'io_sda', sig):     # SDA pin is special, pull UP
            self.iobuf = Pin.PULLUP_33
        elif re.match(r'io_scl', sig):     # SCL pin is special, no pulldown
            self.iobuf = Pin.HIGHZ_33
        elif re.match(r'io_', sig):        # Feather IO gets 3.3V pulldown
            self.iobuf = Pin.PULLDN_33
        else:                              # Default: 3.3V input (for now)
            self.iobuf = Pin.HIGHZ_33   

        # Double-check that DRAM differential pins are set for 1.35V
        A = self.ball in Pin.ECP5_VREF
        B = self.ball in Pin.P135V
        C = self.ball in Pin.RAM_IO
        D = self.ball in Pin.RAM_POWER
        E = self.bank in Pin.DRAM_BANK
        if A or B or C or D or E:
            if self.iobuf != Pin.HIGHZ_135:
                pin_desc = f"{self.ball}, {self.clean_sig}, {self.iobuf}"
                raise Exception(f"DRAM Pin ERR: {pin_desc}")

    def __str__(self):
        """Format pin config as commented nextpnr ECP5 lpf constraints."""
        return (f'# {self.bank}, {self.ball}: {self.sig}\n' +
            f'LOCATE COMP "{self.clean_sig}" SITE "{self.ball}";\n' +
            f'IOBUF PORT "{self.clean_sig}" {self.iobuf};\n')


# Iterate over rows of the CSV file.
# Column format: Bank, Ball, Schematic-notes, 25F-Func, Dual-Func, 85F-Func
pins = []
with open("oc-ecp5u-25f-85f-pinout.csv") as f:
    reader = csv.reader(f)
    _ = next(reader)                                # skip header row
    for (bank, ball, sig, _, _, f85)  in reader:    # loop over data rows
        if re.match(r'CFG_', f85):                  # skip ECP5 config pins
            continue
        if re.match(r'(JTAG|FPGA_RESET|NC)', sig):  # skip non-GPIO pins
            continue
        pins.append(Pin(bank, ball, sig))

# Print the pin config as an lpf constraint file to stdout
print("# SPDX-License-Identifier: ISC")
print("# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny")
print("# Pin constraints for r0.2.1 OrangeCrab 85F (nextpnr-ecp5 lpf format)")
print()
for p in pins:
    print(p)
