#!/usr/bin/python3
# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
"""
Compare the output of my gen_lpf.py script to the r0.2.1 orangecrab pcf file.

I'm feeling paranoid about configuring the output drivers for the DRAM chip
since its absolute max rating on the IO pins is 1.975V and Feather IO is 3.3V.
This script compares my lpf constraint file generator's output to the
orangecrab-examples/verilog pcf file, looking for disagreements on
IO_TYPE=LVCMOS33 vs. IO_TYPE=SSTL135*.

For the SSTL135* stuff, I expect differences because I'm setting all the RAM
pins to SSTL135 class I (SSTL135_I) while orangecrab-examples uses a mix of
single-ended and differential SSTL135 modes. For details on what that modes
mean, refer to Lattice tech note FPGA-TN-02032 1.4, "ECP5 and ECP5-5G sysI/O
Usage Guide", available on the ECP5 product page Documentation section.

This uses hardcoded file paths which assume that my ocfpga repo and the
orangecrab-fpga/orangecrab-examples repo are both checked out in your
$HOME/code/ directory.
"""
from collections import OrderedDict
import csv
import re

from gen_lpf import PinConfig


class LpfGraph:
    def __init__(self, lpf_str, desc):
        """Parse an lpf file string and import its data as a graph.
        """
        self.sites = OrderedDict()  # preserve ordering from lpf file
        self.ports = {}
        self.site_w = 1
        self.comp_w = 1
        self.desc = desc
        locate = re.compile(r'LOCATE COMP "(.*)" SITE "(.*)";')
        iobuf = re.compile(r'IOBUF PORT "([^"]*)" (.*);')
        comment = re.compile(r'#')
        for line in lpf_str.splitlines():          # loop over lpf lines
            if "" == line or comment.match(line):  # skip comments & blanks
                continue
            match_locate = locate.match(line)
            match_iobuf = iobuf.match(line)
            if match_locate:                       # line is LOCATE... ?
                comp = match_locate[1]
                site = match_locate[2]
                self.add_locate(comp, site)
            elif match_iobuf:                      # line is IOBUF... ?
                comp = match_iobuf[1]
                args = match_iobuf[2]
                self.add_iobuf(comp, args)

    def add_locate(self, comp, site):
        """Add data from an lpf file `LOCATE COMP ... SITE ...;` line.
        """
        if site in self.sites:
            raise Exception(f"Redefining site: {comp}, {site}")
        if comp in self.ports:
            raise Exception(f"Redefining comp: {comp}, {site}")
        # Keep track of minimum necessary field widths for names
        self.site_w = max(self.site_w, len(site))
        self.comp_w = max(self.comp_w, len(comp))
        # Store the names
        self.sites[site] = comp
        self.ports[comp] = {}

    def add_iobuf(self, comp, args):
        """Add data from an lpf file `IOBUF PORT ...;` line.
        """
        if not comp in self.ports:
            raise Exception(f"Undefined port: {comp}, {args}")
        # For each space-delimited item in args, split and store the KEY=VALUE
        # args may be 'IO_TYPE=LVCMOS33', 'IO_TYPE=LVCMOS33 PULLMODE=UP', etc
        for a in args.split():
            (k, v) = a.split('=')
            self.ports[comp][k] = v

    def merge_field_widths(self, other):
        """Merge field widths between this LpfGraph and the other one.
        """
        self.site_w = max(self.site_w, other.site_w)
        self.comp_w = max(self.comp_w, other.comp_w)
        other.site_w = self.site_w
        other.comp_w = self.comp_w

    def site_set(self):
        """Return a set of all the site names in this graph.
        """
        return set(self.sites.keys())

    def comp(self, site):
        """Return the comp value for the specified site.
        """
        return self.sites[site]

    def io_type(self, site):
        """Return the IO_TYPE value for the specified site.
        """
        return self.ports[self.sites[site]].get('IO_TYPE', None)

    def banner(self, label):
        """Format a big really-hard-to-miss section heading.
        """
        middle = f"=== {label} ==="
        hr = "=" * len(middle)
        return f"\n{hr}\n{middle}\n{hr}\n"

    def compare(self, other):
        """Format a comparison of pin configs in self and other.
        """
        # Calculate set differences between sites
        A = self.site_set()
        B = other.site_set()
        only_self = A - B
        only_other = B - A
        both = A.intersection(B)

        lines = [f"Comparing {self.desc} with {other.desc}..."]
        # Format pin configs for shared keys the same IO_TYPE value
        lines += [self.banner("Both configs have same IO_TYPE value for:")]
        for k in self.sites.keys():  # use my key ordering
            if k in both:
                if self.io_type(k) == other.io_type(k):
                    lines += ["  " + self.str_for_site(k)]
                    lines += ["  " + other.str_for_site(k), ""]
        lines += [""]

        # Format pin configs for shared keys different IO_TYPE value
        lines += [self.banner("IO_TYPE values **DIFFER** for:")]
        for k in self.sites.keys():  # use my key ordering
            if k in both:
                if self.io_type(k) != other.io_type(k):
                    lines += ["  " + self.str_for_site(k)]
                    lines += ["  " + other.str_for_site(k), ""]
        lines += [""]

        # Format pin configs only found in self, preserving original ordering
        lines += [self.banner(f"Only found in {self.desc}:")]
        for k in self.sites.keys():
            if k in only_self:
                lines += [self.str_for_site(k)]
        if len(only_self) == 0:
            lines += ["--none--"]
        lines += [""]

        # Format pin configs only found in other, preserving original ordering
        lines += [self.banner(f"Only found in {other.desc}:")]
        for k in other.sites.keys():
            if k in only_other:
                lines += [other.str_for_site(k)]
        if len(only_other) == 0:
            lines += ["--none--"]
        lines += [""]

        # Return the big string
        return "\n".join(lines) + "\n"

    def str_for_site(self, site):
        """Format one site as a string with fixed site & comp field widths.
        """
        # Lambda to right align string in specified field width
        pad = lambda s, wide: ' ' * (wide - len(s)) + s
        comp = self.sites[site]
        line = f"{pad(site, self.site_w)} : {pad(comp, self.comp_w)} : "
        args = []
        for k in sorted(self.ports[comp].keys()):
            args.append(f"{k}={self.ports[comp][k]}")
        return line + "  ".join(args)

    def __str__(self):
        """Format graph with one line for each site.
        """
        # Format one line per pin as: `site : comp : args`
        lines = [self.banner(self.desc)]
        lines += [self.str_for_site(s) for s in self.sites.keys()]
        return "\n".join(lines) + "\n"


if __name__ == "__main__":
    # Get graph of lpf string from gen_lpf.py
    graph_mine = LpfGraph(str(PinConfig()), 'config from gen_lpf.py')

    # Get graph of lpf string from orangecrab_r0.2.1.pcf
    filename = "../../../orangecrab-examples/verilog/orangecrab_r0.2.1.pcf"
    grapn_oc = ""
    with open(filename) as f:
        graph_oc = LpfGraph(f.read(), 'config from orangecrab_r0.2.1.pcf')

    # Make them agree on field widths for site and comp
    graph_mine.merge_field_widths(graph_oc)

    # Print a comparison report
    print(graph_mine.compare(graph_oc))
