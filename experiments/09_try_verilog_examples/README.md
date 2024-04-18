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

1. Building libtrellis tools and nextpnr from source is *slow*.


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
