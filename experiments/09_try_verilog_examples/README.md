<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 09 Try Verilog Examples


## Goals:

1. Install [YosysHQ](https://github.com/YosysHQ) CAD suite including `yosys`,
   `nextpnr`, and `ecppack`.

2. Build and run examples from
   [orangecrab-examples/verilog/](https://github.com/orangecrab-fpga/orangecrab-examples/tree/main/verilog)


## Results

*work in progress*


## Lab Notes

1. The README for [YosysHQ](https://github.com/YosysHQ), gives links to their
   OSS CAD suite, along with a commercial CAD suite called Tabby CAD. Until
   just now, I didn't understand the distinction between Tabby CAD (commercial
   superset of the OSS CAD suite) and the OSS CAD suite. I thought there was
   only one YosysHQ CAD suite, and that it was essentially just a packaging of
   yosys, nextpnr, amaranth and some dependencies. It's not that simple.

   The OSS CAD suite [README](https://github.com/YosysHQ/oss-cad-suite-build/),
   describes all all of its prepackaged EDA tools and dependencies. There's a
   lot of stuff included. Reading about this, I'm unsure about installing it
   because of potential interactions with the Debian 12's stable packages I've
   already installed. If possible, I want to avoid setting up workflows that
   depend on bleeding edge builds of standard tools (like python3) as I've been
   bitten by that in the past. (using stable packages helps avoid bitrot)

   For now, I'll try looking for stable releases of `yosys`, `nextpnr`, and
   `ecppack` (do they do stable releases?) and try manually building just
   those.

2. Where to get sources?

   Yosys and nextpnr have their own repositories, but `ecppack` is a part of
   [prjtrellis/libtrellis/tools](https://github.com/YosysHQ/prjtrellis/tree/1.4/libtrellis/tools)
   (libtrellis tools from Project Trellis).

   These are the current releases of yosys, nextpnr, and prjtrellis:

   - yosys
     [0.40 release](https://github.com/YosysHQ/yosys/releases/tag/yosys-0.40)
     page with a link to
     [yosys-0.40.tar.gz](https://github.com/YosysHQ/yosys/archive/refs/tags/yosys-0.40.tar.gz)
     source tarball

   - nextpnr
     [0.7 release](https://github.com/YosysHQ/nextpnr/releases/tag/nextpnr-0.7)
     page with a link to
     [nextpnr-0.7.tar.gz](https://github.com/YosysHQ/nextpnr/archive/refs/tags/nextpnr-0.7.tar.gz)
     source tarball

   - prjtrellis
     [1.4 release](https://github.com/YosysHQ/prjtrellis/releases/tag/1.4)
     page with a link to
     [1.4.tar.gz](https://github.com/YosysHQ/prjtrellis/archive/refs/tags/1.4.tar.gz)
     source tarball

3. My plan is to use `make` to download the source tarballs, verify they match
   expected SHA256 digests, build the tools, then install the tools to `~/bin`.
   Currently I'm working on this in [Makefile](Makefile).
