#!/usr/bin/python3
# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
import math

# Make a table that covers a range of baud rates. Include old low rates to be
# sure the timer has enough bits.
baud_rates = [300, 1200, 2400, 9600, 19200, 115200]

def period(baud):
    """Calculate period of this baud rate in 48 MHz system clock ticks."""
    return 48e6 / baud

def timer_bits(baud):
    """Calculate timer bits needed to represent period of this baud rate."""
    return math.ceil( math.log2( period(baud)))

def timer_seed(baud):
    """Calculate initial timer value to overflow after period clock ticks."""
    bits = timer_bits(baud)
    overflow = 2 ** bits
    return overflow - period(baud)

def update_width(k, v):
    """Keep track of field widths to help format table."""
    old = widths.get(k, 0)
    if v > old:
        widths[k] = v

def fmt_row(cells, widths):
    pads = [" " * (w - len(c)) for (w, c) in zip(widths, cells)]
    cells = [f"{p}{c}" for (p, c) in zip(pads, cells)]
    return f"| {' | '.join(cells)} |"

def fmt_header(widths):
    return fmt_row(["-" * w for w in widths], widths)

widths = [0, 0, 0, 0, 0]
rows = [['baud', 'period', 'timer_bits', 'timer_seed', 'seed + period']]
for b in baud_rates:
    p = round(period(b), 3)
    seed = round(timer_seed(b))
    sPlusP = round(seed + p, 1)
    rows += [[f"{b}", f"{p:.3f}", str(timer_bits(b)), str(seed), str(sPlusP)]]
for row in rows:
    for (i, cell) in enumerate(row):
        if len(cell) > widths[i]:
            widths[i] = len(cell)
print(fmt_row(rows[0], widths))
print(fmt_header(widths))
for r in rows[1:]:
    print(fmt_row(r, widths))

"""
|   baud |     period | timer_bits | timer_seed | seed + period |
| ------ | ---------- | ---------- | ---------- | ------------- |
|    300 | 160000.000 |         18 |     102144 |      262144.0 |
|   1200 |  40000.000 |         16 |      25536 |       65536.0 |
|   2400 |  20000.000 |         15 |      12768 |       32768.0 |
|   9600 |   5000.000 |         13 |       3192 |        8192.0 |
|  19200 |   2500.000 |         12 |       1596 |        4096.0 |
| 115200 |    416.667 |          9 |         95 |         511.7 |
"""
