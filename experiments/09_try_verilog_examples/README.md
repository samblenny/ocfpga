<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 09 Try Verilog Examples


## Goals:

1. Install [YosysHQ](https://github.com/YosysHQ) CAD tools including `yosys`,
   `nextpnr`, and `ecppack`.

2. Build and run the blink and pwm_rainbow examples from
   [orangecrab-examples/verilog/](https://github.com/orangecrab-fpga/orangecrab-examples/tree/main/verilog)


## Results

1. Compiling these tools from scratch is kinda slow, but it has the advantage
   of using (hopefully stable) release versions rather than nightlies. If you
   enjoy adventure and danger, you might prefer a prebuilt nightly release from
   [YosysHQ/oss-cad-suite-build](https://github.com/YosysHQ/oss-cad-suite-build).

2. I wrote a [Makefile](Makefile) to download, build, and install libtrellis tools
   (`ecppack`), `nextpnr-ecp5`, and `yosys`. The default install prefix is
   `~/bin/yosyshq`. But, `make install` also creates symlinks for
   `~/bin/yosys`, `~/bin/nextpnr-ecp5`, and `~/bin/ecppack`. This is convenient
   for me since I already have `$HOME/bin` in my path and wanted an easy way to
   uninstall the yosyshq tools during testing (`rm -r ~/bin/yosyshq`).

   If you want a different install location for the binaries, you can do `make
   PREFIX=...`. If you already have other YosysHQ tools installed in `~/bin`,
   you might want to revise the Makefile.

   To see the source code release versions I used, read the Makefile.

   As-is, this Makefile will only work on Debian and Debian-based distros (e.g.
   Ubuntu) that have `dpkg` and `apt`. But, you could modify it simply enough.

   Usage:

   First, run `make check-deps` to check if you have the dev dependency packages
   installed which are needed to build libtrellis tools, nextpnr, and yosys:

    ```console
    $ cd ~/code/ocfpga/experiments/09_try_verilog_examples
    $ make check-deps
    Checking for build dependencies with 'dpkg -s' ...
      cmake: OK
      clang: OK
      python3-dev: OK
      cmake: OK
      clang: OK
      python3-dev: OK
      libboost-dev: OK
      libboost-filesystem-dev: OK
      libboost-thread-dev: OK
      libboost-program-options-dev: OK
      libboost-iostreams-dev: OK
      libboost-dev: OK
      libeigen3-dev: OK
      build-essential: OK
      clang: OK
      bison: MISSING
      flex: MISSING
      libreadline-dev: OK
      gawk: OK
      tcl-dev: OK
      libffi-dev: OK
      git: OK
      graphviz: OK
      xdot: OK
      pkg-config: OK
      python3: OK
      libboost-system-dev: MISSING
      libboost-python-dev: MISSING
      libboost-filesystem-dev: OK
      zlib1g-dev: OK
    ERROR: you need to install missing packages
      try 'sudo apt install  bison flex libboost-system-dev libboost-python-dev'
    make: *** [Makefile:77: check-deps] Error 1
    ```

   Install any missing build dependencies (assuming a Debian-based distro):

    ```console
    $ sudo apt install  bison flex libboost-system-dev libboost-python-dev
    ```

   Once you have the dev dependencies, run `make install` (this will download
   release archives, verify SHA256 digests, then build and install to `~/bin`
   and `~/bin/yosyshq`. It takes a while to finish):

    ```console
    $ cd ~/code/ocfpga/experiments/09_try_verilog_examples
    $ make install
    ```

   Verify the install worked (this assumes `$HOME/bin` is in your `$PATH`):

    ```console
    $ ecppack --version
    Project Trellis ecppack Version a33e120
    $ nextpnr-ecp5 --version
    "nextpnr-ecp5" -- Next Generation Place and Route (Version a33e120)
    $ yosys --version
    Yosys 0.40 (git sha1 a1bb0255d65, g++ 12.2.0-14 -fPIC -Os)
    ```

3. Building the orangecrab-examples/verilog examples for
   [verilog/blink](https://github.com/orangecrab-fpga/orangecrab-examples/blob/02358e7f53f5e3b450e142bc343ca9c7ae3cb5a9/verilog/blink/)
   and
   [verilog/pwm_rainbow](https://github.com/orangecrab-fpga/orangecrab-examples/blob/02358e7f53f5e3b450e142bc343ca9c7ae3cb5a9/verilog/pwm_rainbow/)
   was easy. I didn't need to modify the existing Makefiles.

   To build the blink example for OrangeCrab 85F and load it over JTAG using a
   Tigard board:

    ```console
    $ cd ~/code/orangecrab-examples/verilog/blink
    $ make DENSITY=85F
    ...
    $ openFPGALoader -c tigard --freq 1M -f --file-type raw --verify -o 0x80000 blink.dfu
    ...
    ```

   The result was a cycling LED pattern of red, green, amber, off.

   To build the pwm_rainbow example for OrangeCrab 85F and load it over JTAG
   using a Tigard board:

    ```console
    $ cd ~/code/orangecrab-examples/verilog/pwm_rainbow
    $ make DENSITY=85F
    ...
    $ openFPGALoader -c tigard --freq 1M -f --file-type raw --verify -o 0x80000 pwm_rainbow.dfu
    ...
    ```

   Yosys and nextpnr output a lot of log messages. Many of them are obscure and
   difficult to understand, but there are also some very useful messages about
   timing closure and LUT usage. For examples, check out the snippets in my lab
   notes below.

4. I saved prebuilt binaries for `blink.dfu` and `pwm_rainbow.dfu` here in the
   [./prebuilt](prebuilt) folder.


## Lab Notes


### Build and install YosysHQ EDA tools

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
     source tarball. Also, the Makefile for yosys 0.40 includes a step to
     automatically download and build
     [YosysHQ/abc commit 0cd90d0](https://github.com/YosysHQ/abc/tree/0cd90d0d2c5338277d832a1d890bed286486bcf5)

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

   - prjtrellis-db
     [commit ce8cdaf](https://github.com/YosysHQ/prjtrellis-db/tree/ce8cdafe7a8c718f0ec43895894b668a479ba33f)
     has ECP5 bitstream database files for the submodule reference in the
     prjtrellis 1.4 release. The database files need to be either copied or
     recursively cloned into `prjtrellis/database/`. Since I'm using archives,
     I got the database files from a github commit archive zip download URL:
     [ce8cdafe7a8c718f0ec43895894b668a479ba33f.zip](https://github.com/YosysHQ/prjtrellis-db/archive/ce8cdafe7a8c718f0ec43895894b668a479ba33f.zip)

3. My plan is to use `make` to download the source tarballs, verify they match
   expected SHA256 digests, build the tools, then install the tools to `~/bin`.
   Currently I'm working on this in [Makefile](Makefile).

   Here's a simplified example of the method I'm working on for using `make`
   rules to download, verify, and extract source tarballs:

    ```make
    .POSIX:

    YOSYS_TAR = cache/yosys-0.40.tar.gz
    YOSYS_URL = https://github.com/YosysHQ/yosys/archive/refs/tags/yosys-0.40.tar.gz

    # Expected SHA256 digests for source tarballs
    SHA256 = src_tarballs.SHA256

    # Downloaders
    CURL = curl --fail -L -o
    WGET = wget --no-verbose -O

    # Unpack sources into build dir
    unpack-src: $(YOSYS_TAR) $(NEXTPNR_TAR) $(TRELLIS_TAR)
    	shasum -a 256 --check $(SHA256)
    	@mkdir -p build
    	tar -C build -xf $(YOSYS_TAR)
    	tar -C build -xf $(NEXTPNR_TAR)
    	tar -C build -xf $(TRELLIS_TAR)

    # Download source tarballs and verify SHA256 digests
    get-src: $(YOSYS_TAR) $(NEXTPNR_TAR) $(TRELLIS_TAR)
    	shasum -a 256 --check $(SHA256)

    # Download yosys tarball to cache using curl or wget
    $(YOSYS_TAR):
    	@mkdir -p cache
    	@CURL_="$(CURL) $(YOSYS_TAR) $(YOSYS_URL)"; \
    	WGET_="$(WGET) $(YOSYS_TAR) $(YOSYS_URL)"; \
    	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
    	else echo $$WGET_; $$WGET_; fi
    ```

   I learned a new trick for combining `make` variables, shell variables, and
   shell conditional expressions. For example, consider the `$(YOSYS_TAR)`
   rule:

    ```make
    	@CURL_="$(CURL) ..."; \
    	WGET_="$(CURL) ..."; \
    	if which curl ...; then ... $$CURL_ ...;
    	else ... $$WGET_ ...; fi"; \
    ```

   The point is to have `make` automatically use `curl` or `wget`, assuming
   that one or the other is probably available (`curl` for macOS, `wget` for
   Debian or Ubuntu).

   In the example above, I'm defining two `make` variables, `CURL_` and `WGET_`
   with equivalent commands to download a source archive URL. The shell `if
   then else fi` expression uses `which curl` to select a download method based
   on whether `curl` or `wget` is available. I do this because it lets me start
   editing and testing the Makefile on macOS (only curl installed), then move
   to Debian (only wget installed) to test the build steps that require
   compilers.

   Going to all this trouble might seem odd, and unusual compared to normal
   developer practices. But there's carefully considered reasoning behind it.
   Sticking to standard packages of stable distros, and sticking to POSIX
   syntax as much as possible, helps to avoid bitrot. Testing the workflow,
   at least in part, on both a BSD-based shell and a GNU/Linux shell, helps
   ensure I stick to POSIX stuff. All that means I should hopefully have less
   maintenance and better code reusability in the future. Also, separating
   tasks between operating systems helps reduce the odds of getting my
   authentication credentials stolen by malware.

   Here's another trick using a similar technique of moderately complex shell
   expressions with backslash line continuations:

    ```make
    # nextpnr build dependencies (.deb packages for Debian or Ubuntu)
    NEXTPNR_DEPS = cmake clang python3-dev libboost-all-dev libeigen3-dev

    # Check build dependencies for missing dev packages
    check-deps:
    	@echo "Checking for build dependencies with 'dpkg -s' ..."
    	@MISSING_DEPS=""; \
    	for dep in $(NEXTPNR_DEPS); do \
    		if dpkg -s $$dep 2>/dev/null >/dev/null; \
    			then echo "  $$dep: OK"; \
    			else MISSING_DEPS="$$MISSING_DEPS $$dep"; \
    				echo "  $$dep: MISSING"; \
    		fi; \
    	done; \
    	if [ "$$MISSING_DEPS" = "" ]; \
    		then echo "SUCCESS! Build dependencies are installed"; \
    		else echo ERROR: you need to install missing packages; \
    			echo "  try 'sudo apt install $$MISSING_DEPS'"; \
    			false; \
    	fi
    ```

   When I use that rule to run a `make check-deps`, the output looks like this:

    ```console
    $ make check-deps
    Checking for build dependencies with 'dpkg -s' ...
      cmake: OK
      clang: OK
      python3-dev: OK
      libboost-all-dev: MISSING
      libeigen3-dev: MISSING
    ERROR: you need to install missing packages
      try 'sudo apt install  libboost-all-dev libeigen3-dev'
    make: *** [Makefile:44: check-deps] Error 1
    ```

   The point is being able to generate that second to last line where it
   suggests a `sudo apt install ...` incantation to install missing packages.
   This approach may seem weird to people who are used to trusting language
   level package managers to make extensive modifications to their systems. I
   do it this way because I don't trust most package managers.

   Anyhow, the `make` rule above, like the last one, uses a mix of `$(...)`
   make variable substitutions and `$$...` shell variable substitutions to
   combine shell looping, shell conditionals, and make rule logic. The result
   is that I can have conditional logic in my `make` rules while staying within
   the bounds of POSIX `make` syntax. You could do similar things using GNU
   extensions, but I prefer using boring old POSIX stuff and stable-branch
   distro packages whenever possible.

4. Continuing to work on my Makefile...

   After trying `apt install libboost-all-dev`, which wanted to install 400+ MB
   of random stuff, I decided to narrow it down to just the specific `libboost`
   packages listed in the nextpnr readme...

    ```console
    $ sudo apt install  libboost-dev libboost-filesystem-dev libboost-thread-dev \
      libboost-program-options-dev libboost-iostreams-dev libboost-dev \
      libeigen3-dev
    $ make check-deps
    Checking for build dependencies with 'dpkg -s' ...
      cmake: OK
      clang: OK
      python3-dev: OK
      libboost-dev: OK
      libboost-filesystem-dev: OK
      libboost-thread-dev: OK
      libboost-program-options-dev: OK
      libboost-iostreams-dev: OK
      libboost-dev: OK
      libeigen3-dev: OK
    SUCCESS! Build dependencies are installed
    ```

   Reading further in the nextpnr readme, it says I need to build prjtrellis
   first so I can specify its install location to `cmake`. So, now I'll work
   on Makefile to add rules to install libtrellis/tools.

   [*time passes... works on Makefile*]

   After checking the dependencies for all three source packages and adding
   them to my Makefile, it looks like I need to install more stuff:

    ```console
    $ sudo apt install  bison flex libreadline-dev gawk tcl-dev graphviz xdot \
      libboost-system-dev libboost-python-dev
    ```

   [*more work on Makefile*]

   It turns out that if you use the release tarball for prjtrellis, rather than
   doing a recursive git clone, `nextpnr`'s make will get mad about missing
   database files. The database files it wants are from
   [YosysHQ/prjtrellis-db](https://github.com/YosysHQ/prjtrellis-db). For the
   `1.4` tag of prjtrellis, the prjtrellis-db submodule reference is for
   [commit ce8cdaf](https://github.com/YosysHQ/prjtrellis-db/tree/ce8cdafe7a8c718f0ec43895894b668a479ba33f).

   Since I've been building my Makefile around tarballs and SHA256 digests, I
   will try making Github zip archive URL for that commit rather than doing the
   git recursive clone thing.

   [*more work on Makefile*]

   It's important to specify `-DCMAKE_INSTALL_PREFIX=...` for `nextpnr` `cmake`
   if you don't want to use the default install directory of `/usr/local`. The
   compile time for `nextpnr` is very long. It's not fun to wait for the build
   to finish only to discover during `make install` that the PREFIX is wrong.

5. Current status: Makefile downloads, builds, and installs libtrellis tools
   and nextpnr-ecp5. Now I need to teach it how to build and install yosys.

   [*works on yosys make targets*]

   The yosys Makefile automatically downloads and builds a thing called `ABC`,
   which is used to optimize for delay when mapping networks to LUTs. From
   reading the yosys 0.40 release's
   [Makefile](https://github.com/YosysHQ/yosys/blob/yosys-0.40/Makefile#L163-L172),
   the ABC source code comes from
   [YosysHQ/abc commit 0cd90d0](https://github.com/YosysHQ/abc/tree/0cd90d0d2c5338277d832a1d890bed286486bcf5).

   Compiling is slow enough that I've been running a second terminal with `top`
   to monitor CPU and RAM use. Compiling yosys is mostly CPU-bound with low RAM
   usage. Nextpnr was CPU-bound at times, but some of the database related
   stages were RAM-bound, using up to 700 MB of swap on a box with 4 GB of RAM.

6. [Makefile](Makefile) seems to be ready. This works:

    ```console
    $ make install
    ...
    $ ecppack --version
    Project Trellis ecppack Version 4a27146
    $ nextpnr-ecp5 --version
    "nextpnr-ecp5" -- Next Generation Place and Route (Version 3832512)
    $ yosys --version
    Yosys 0.40 (git sha1 a1bb0255d65, g++ 12.2.0-14 -fPIC -Os)
    ```

7. To test, I uninstalled everything from `~/bin`, did a `make dist-clean`, and
   rebuilt from scratch with `make install`. It worked fine. Build and install
   took 39 minutes to finish using a 1.4 GHz Core i5-4260U with 4 GB RAM, SATA
   SSD, and Debian Bookworm.


### Build and run OrangeCrab Verilog examples

8. Take a look at the orangecrab-examples/verilog/blink
   [Makefile](https://github.com/orangecrab-fpga/orangecrab-examples/blob/02358e7f53f5e3b450e142bc343ca9c7ae3cb5a9/verilog/blink/Makefile)...

    ```console
    $ cd ~/code/orangecrab-examples/verilog/blink
    $ less Makefile
    ...
    ```

   The first thing I see notice is `DENSITY=25F` So, it looks like I will need
   to use `make DENSITY=85F ...`. So, I'll try it...

    ```console
    $ cd ~/code/orangecrab-examples/verilog/blink
    $ make DENSITY=85F
    yosys -p "read_verilog blink.v; synth_ecp5 -json blink.json"
    ...
    nextpnr-ecp5 --json blink.json --textcfg blink_out.config --85k --package CSFBGA285 --lpf ../orangecrab_r0.2.1.pcf
    Info: constraining clock net 'clk48' to 48.00 MHz
    ...
    Info: pin 'rgb_led0_r$tr_io' constrained to Bel 'X126/Y83/PIOA'.
    Info: pin 'rgb_led0_g$tr_io' constrained to Bel 'X126/Y86/PIOA'.
    Info: pin 'rgb_led0_b$tr_io' constrained to Bel 'X126/Y50/PIOC'.
    Info: pin 'clk48$tr_io' constrained to Bel 'X71/Y0/PIOA'.
    ...
    Info: Device utilisation:
    Info: 	          TRELLIS_IO:     4/  365     1%
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
    Info: 	          TRELLIS_FF:    26/83640     0%
    Info: 	        TRELLIS_COMB:    35/83640     0%
    Info: 	        TRELLIS_RAMW:     0/10455     0%
    ...
    Info: Max frequency for clock '$glbnet$clk48$TRELLIS_IO_IN': 307.69 MHz (PASS at 48.00 MHz)

    Info: Max delay posedge $glbnet$clk48$TRELLIS_IO_IN -> <async>: 2.47 ns
    ...
    Info: Program finished normally.
    ecppack --compress --freq 38.8 --input blink_out.config --bit blink.bit
    cp -a blink.bit blink.dfu
    dfu-suffix -v 1209 -p 5af0 -a blink.dfu
    rm blink.json blink.bit blink_out.config
    ```

   That seems good so far. I don't like the OrangeCrab's DFU reset procedure
   where you have to unplug the USB cable, hold the button, then plug the cable
   back in. Since I have JTAG programming set up, I'll use `openFPGALoader`:

    ```console
    $ openFPGALoader -c tigard --freq 1M -f --file-type raw --verify -o 0x80000 blink.dfu
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
    ```

   It works! The LED is cycling through a pattern of red, green, amber, off.

9. Save a copy of `blink.dfu` to my [prebuilt](prebuilt) folder:

    ```console
    $ cd ~/code/ocfpga/experiments/09_try_verilog_examples
    $ mkdir prebuilt
    $ cp ../../../orangecrab-examples/verilog/blink/blink.dfu prebuilt/
    $ cp ../../LICENSES/LICENSE_orangecrab-examples prebuilt/
    $ cat <<EOF > prebuilt/README.md
    # orangecrab-examples/verilog prebuilt binaries

    These OrangeCrab 85F DFU binaries were built from the source code at
    https://github.com/orangecrab-fpga/orangecrab-examples/tree/main/verilog
    EOF
    ```

10. Try the
    [verilog/pwm_rainbow](https://github.com/orangecrab-fpga/orangecrab-examples/tree/02358e7f53f5e3b450e142bc343ca9c7ae3cb5a9/verilog/pwm_rainbow)
    example:

    ```console
    $ cd ~/code/orangecrab-examples/verilog/pwm_rainbow
    $ less readme.md
    $ less Makefile
    $ make DENSITY=85F
    yosys -s "pwm_rainbow.ys"
    ...
    -- Executing script file `pwm_rainbow.ys' --
    ...
    nextpnr-ecp5 --json pwm_rainbow.json --textcfg pwm_rainbow_out.config --85k --package CSFBGA285 --lpf ../orangecrab_r0.2.1.pcf
    ...
    Info: pin 'usr_btn$tr_io' constrained to Bel 'X0/Y83/PIOC'.
    Info: pin 'rst_n$tr_io' constrained to Bel 'X15/Y95/PIOB'.
    Info: pin 'rgb_led0_r$tr_io' constrained to Bel 'X126/Y83/PIOA'.
    Info: pin 'rgb_led0_g$tr_io' constrained to Bel 'X126/Y86/PIOA'.
    Info: pin 'rgb_led0_b$tr_io' constrained to Bel 'X126/Y50/PIOC'.
    Info: pin 'clk48$tr_io' constrained to Bel 'X71/Y0/PIOA'.
    ...
    Info: Device utilisation:
    Info: 	          TRELLIS_IO:     6/  365     1%
    Info: 	                DCCA:     1/   56     1%
    Info: 	              DP16KD:     0/  208     0%
    Info: 	          MULT18X18D:     2/  156     1%
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
    Info: 	          TRELLIS_FF:    77/83640     0%
    Info: 	        TRELLIS_COMB:   215/83640     0%
    Info: 	        TRELLIS_RAMW:     0/10455     0%
    ...
    Info: Max frequency for clock '$glbnet$clk48$TRELLIS_IO_IN': 89.08 MHz (PASS at 48.00 MHz)

    Info: Max delay <async>                             -> posedge $glbnet$clk48$TRELLIS_IO_IN: 1.57 ns
    Info: Max delay posedge $glbnet$clk48$TRELLIS_IO_IN -> <async>                            : 7.48 ns
    ...
    Info: Program finished normally.
    ecppack --compress --freq 38.8 --input pwm_rainbow_out.config --bit pwm_rainbow.bit
    cp -a pwm_rainbow.bit pwm_rainbow.dfu
    dfu-suffix -v 1209 -p 5af0 -a pwm_rainbow.dfu
    rm pwm_rainbow.bit pwm_rainbow_out.config pwm_rainbow.ys pwm_rainbow.json
    ```

    Looks good. Now try flashing it...

    ```console
    $ openFPGALoader -c tigard --freq 1M -f --file-type raw --verify -o 0x80000 pwm_rainbow.dfu
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
    ```

    That works! The LED is doing a nice smooth rainbow fade. It's smoother and a
    lot less frantic looking compared to the bootloader.

    Now save a copy of `pwm_rainbow.dfu` to my [prebuilt](prebuilt) folder...

    ```console
    $ cd ~/code/ocfpga/experiments/09_try_verilog_examples
    $ cp ../../../orangecrab-examples/verilog/pwm_rainbow/pwm_rainbow.dfu prebuilt/
    ```
