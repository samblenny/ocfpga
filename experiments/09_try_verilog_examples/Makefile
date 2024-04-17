# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
#
# Download and build yosys, nexpnr, ecppack, and ecpunpack to ~/bin/yosyshq
#
.POSIX:

# Default install prefix for built tools
PREFIX ?= $(HOME)/bin/yosyshq

# Download cache filepaths for source archives
YOSYS_TAR = cache/yosys-0.40.tar.gz
NEXTPNR_TAR = cache/nextpnr-0.7.tar.gz
TRELLIS_TAR = cache/prjtrellis-1.4.tar.gz
DATABASE_ZIP = cache/prjtrellis-db-ce8cdaf.zip

# Source archive URLs
YOSYS_URL   = https://github.com/YosysHQ/yosys/archive/refs/tags/yosys-0.40.tar.gz
NEXTPNR_URL = https://github.com/YosysHQ/nextpnr/archive/refs/tags/nextpnr-0.7.tar.gz
TRELLIS_URL = https://github.com/YosysHQ/prjtrellis/archive/refs/tags/1.4.tar.gz
# This is from the submodule ref (ce8cdaf) in prjtrellis tag 1.4:
DATABASE_URL = https://github.com/YosysHQ/prjtrellis-db/archive/ce8cdafe7a8c718f0ec43895894b668a479ba33f.zip

# Expected SHA256 digests for source tarballs
YOSYS_SHA = yosys.SHA256
NEXTPNR_SHA = nextpnr.SHA256
TRELLIS_SHA = prjtrellis.SHA256
DATABASE_SHA = prjtrellis-db.SHA256

# Downloaders
CURL = curl --fail -L -o
WGET = wget --no-verbose -O

# Build directories (unpacked from tarballs)
BUILD_YOSYS = build/yosys-yosys-0.40
BUILD_NEXTPNR = build/nextpnr-nextpnr-0.7
BUILD_TRELLIS = build/prjtrellis-1.4
BUILD_DATABASE = build/prjtrellis-db-ce8cdafe7a8c718f0ec43895894b668a479ba33f

# Compiled binaries
ECPPACK_BIN = $(BUILD_TRELLIS)/libtrellis/ecppack
NEXTPNR_BIN = $(BUILD_NEXTPNR)/nextpnr-ecp5
YOSYS_BIN = $(BUILD_YOSYS)/yosys

# Installed library and binary locations (not symlinks)
LIBTRELLIS_SO = $(PREFIX)/lib/trellis/libtrellis.so
ECPPACK_INST = $(PREFIX)/bin/ecppack
NEXTPNR_INST = $(PREFIX)/bin/nextpnr-ecp5
YOSYS_INST = $(PREFIX)/bin/yosys

# Installed tool symlinks
LN_DIR = $(HOME)/bin
LN_ECPPACK = $(LN_DIR)/ecppack
LN_ECPUNPACK = $(LN_DIR)/ecpunpack
LN_NEXTPNR = $(LN_DIR)/nextpnr-ecp5
LN_YOSYS = $(LN_DIR)/yosys

# nextpnr build dependencies (.deb packages for Debian or Ubuntu)
TRELLIS_DEPS = cmake clang python3-dev
NEXTPNR_DEPS = cmake clang python3-dev libboost-dev libboost-filesystem-dev \
 libboost-thread-dev libboost-program-options-dev libboost-iostreams-dev \
 libboost-dev libeigen3-dev
YOSYS_DEPS = build-essential clang bison flex libreadline-dev gawk tcl-dev \
 libffi-dev git graphviz xdot pkg-config python3 libboost-system-dev \
 libboost-python-dev libboost-filesystem-dev zlib1g-dev


# Default target is usage message
.PHONY: all
all:
	@echo "available targets: get-src unpack-src clean dist-clean"

# Check build dependencies with dpkg to identify any missing dev packages
.PHONY: check-deps
check-deps:
	@echo "Checking for build dependencies with 'dpkg -s' ..."
	@MISSING_DEPS=""; \
	for dep in $(TRELLIS_DEPS) $(NEXTPNR_DEPS) $(YOSYS_DEPS); do \
		if dpkg -s $$dep 2>/dev/null >/dev/null; then \
			echo "  $$dep: OK"; \
			else MISSING_DEPS="$$MISSING_DEPS $$dep"; \
				echo "  $$dep: MISSING"; \
		fi; \
	done; \
	if [ "$$MISSING_DEPS" = "" ]; then \
		echo SUCCESS! Build dependencies are installed; \
		else echo ERROR: you need to install missing packages; \
			echo "  try 'sudo apt install $$MISSING_DEPS'"; \
			false; \
	fi

# Install tools to $(PREFIX) with symlinks in $HOME/bin. This is a compromise
# between easy access to tools (assuming ~/bin is in $PATH) and having the
# built libraries (libtrellis.so, etc) contained in a directory that isn't
# confusingly mixed in with a bunch of other stuff. Idea is that it should be
# pretty safe to do an `rm -r` on $(PREFIX) to uninstall.
.PHONY: install
install: $(LIBTRELLIS_SO) $(LN_NEXTPNR) $(LN_YOSYS)

# DANGER! DANGER! DANGER!
# Be careful to check for possible name and path conflicts here if you use
# this on a system which installs YosysHQ tools by other means than just this
# Makefile.
.PHONY: uninstall
uninstall:
	@echo 'To uninstall, you can run these commands (but check them first!):'
	@echo "  rm $(LN_YOSYS) $(LN_ECPPACK) $(LN_ECPUNPACK) $(LN_NEXTPNR)"
	@echo "  rm -r $(PREFIX)"

# Install yosys
$(LN_YOSYS): $(YOSYS_INST)
	echo adding symlink: $(LN_YOSYS); \
	ln -s $(YOSYS_INST) $(LN_YOSYS)
$(YOSYS_INST): $(YOSYS_BIN)
	cd $(BUILD_YOSYS); \
	make PREFIX=$(PREFIX) install

# Install nextpnr-ecp5
$(LN_NEXTPNR): $(NEXTPNR_INST)
	echo adding symlink: $(LN_NEXTPNR); \
	ln -s $(NEXTPNR_INST) $(LN_NEXTPNR)
$(NEXTPNR_INST): $(NEXTPNR_BIN)
	cd $(BUILD_NEXTPNR); \
	make install

# Compile yosys
$(YOSYS_BIN): $(BUILD_YOSYS)
	@cd $(BUILD_YOSYS); \
	make -j$$(nproc) PREFIX=$(PREFIX)

# Compile nextpnr tools
# CAUTION: This won't compile unless libtrellis was already built and
# installed. In particular, you need to get the database files from
# prjtrellis-db and put them in prjtrellis/database/ before building and
# installing prjtrellis. If nextpnr's make can't find libtrellis.so or the
# installed database files, it will die with an error.
# ANOTHER CAUTION: Some of this is really RAM intensive, so I'm only using
# 1 compile thread
$(NEXTPNR_BIN): $(LIBTRELLIS_SO) $(BUILD_NEXTPNR)
	@cd $(BUILD_NEXTPNR) && \
	cmake . -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=$(PREFIX) && \
	make -j1

# Install libtrellis tools. This target is set up so the nextpnr compile
# target can use a libtrellis.so prerequisite as a proxy for whether all the
# libtrellis tools have been installed.
$(LIBTRELLIS_SO): $(ECPPACK_BIN)
	@mkdir -p $$HOME/bin
	cd $(BUILD_TRELLIS)/libtrellis && make install
	@if [ ! -L $(LN_ECPPACK) ]; then \
		echo adding symlink: $(LN_ECPPACK); \
		ln -s $(PREFIX)/bin/ecppack $(LN_ECPPACK); fi
	@if [ ! -L $(LN_ECPUNPACK) ]; then \
		echo adding symlink: $(LN_ECPUNPACK); \
		ln -s $(PREFIX)/bin/ecpunpack $(LN_ECPUNPACK); fi

# Compile libtrellis tools (use ecppack binary as proxy for all the tools).
# These must be compiled and installed as a dependency of compiling nextpnr.
$(ECPPACK_BIN): $(BUILD_TRELLIS)
	@cd $(BUILD_TRELLIS)/libtrellis && \
	cmake . -DCMAKE_INSTALL_PREFIX=$(PREFIX) && \
	make -j$$(nproc)

# Verify and unpack all the source archives
.PHONY: unpack-src
unpack-src: $(BUILD_TRELLIS) $(BUILD_NEXTPNR) $(BUILD_YOSYS)

# Verify and unpack prjtrellis source archive. Rather than doing a recursive
# git clone to get the prjtrellis-db as a submodule, just get it from a zip
# archive and copy the files into place in prjtrellis/database/
$(BUILD_TRELLIS): $(TRELLIS_TAR) $(DATABASE_ZIP)
	@if [ ! -d $(BUILD_TRELLIS) ]; then \
		echo "Unpacking $(TRELLIS_TAR) ..."; \
		mkdir -p build && \
		shasum -a 256 --check $(TRELLIS_SHA) && \
		tar -C build -xf $(TRELLIS_TAR); \
		fi && \
	if [ ! -d $(BUILD_TRELLIS)/database/ECP5 ]; then \
		echo "Unpacking $(DATABASE_ZIP) ..."; \
		shasum -a 256 --check $(DATABASE_SHA) && \
		unzip -o -q -d build $(DATABASE_ZIP) && \
		echo "Copying $(BUILD_DATABASE)/ to $(BUILD_TRELLIS)/database/ ..."; \
		cp -rp $(BUILD_DATABASE)/* $(BUILD_TRELLIS)/database/; \
		fi

# Verify and unpack nextpnr source archive
$(BUILD_NEXTPNR): $(NEXTPNR_TAR)
	@if [ ! -d $(BUILD_NEXTPNR) ]; then \
		echo "Unpacking $(NEXTPNR_TAR) ..."; \
		mkdir -p build; \
		shasum -a 256 --check $(NEXTPNR_SHA); \
		tar -C build -xf $(NEXTPNR_TAR); fi

# Verify and unpack yosys source archive
$(BUILD_YOSYS): $(YOSYS_TAR)
	@if [ ! -d $(BUILD_YOSYS) ]; then \
		echo "Unpacking $(YOSYS_TAR) ..."; \
		mkdir -p build; \
		shasum -a 256 --check $(YOSYS_SHA); \
		tar -C build -xf $(YOSYS_TAR); fi

# Download source tarballs and verify SHA256 digests
.PHONY: get-src
get-src: $(YOSYS_TAR) $(NEXTPNR_TAR) $(TRELLIS_TAR) $(DATABASE_ZIP)

# Download prjtrellis tarball to cache using curl or wget
$(TRELLIS_TAR):
	@mkdir -p cache
	@CURL_="$(CURL) $(TRELLIS_TAR) $(TRELLIS_URL)"; \
	WGET_="$(WGET) $(TRELLIS_TAR) $(TRELLIS_URL)"; \
	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
	else echo $$WGET_; $$WGET_; fi
	shasum -a 256 --check $(TRELLIS_SHA)

# Download prjtrellis-db zip archive to cache using curl or wget
$(DATABASE_ZIP):
	@mkdir -p cache
	@CURL_="$(CURL) $(DATABASE_ZIP) $(DATABASE_URL)"; \
	WGET_="$(WGET) $(DATABASE_ZIP) $(DATABASE_URL)"; \
	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
	else echo $$WGET_; $$WGET_; fi
	shasum -a 256 --check $(DATABASE_SHA)

# Download nextpnr tarball to cache using curl or wget
$(NEXTPNR_TAR):
	@mkdir -p cache
	@CURL_="$(CURL) $(NEXTPNR_TAR) $(NEXTPNR_URL)"; \
	WGET_="$(WGET) $(NEXTPNR_TAR) $(NEXTPNR_URL)"; \
	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
	else echo $$WGET_; $$WGET_; fi
	shasum -a 256 --check $(NEXTPNR_SHA)

# Download yosys tarball to cache using curl or wget
$(YOSYS_TAR):
	@mkdir -p cache
	@CURL_="$(CURL) $(YOSYS_TAR) $(YOSYS_URL)"; \
	WGET_="$(WGET) $(YOSYS_TAR) $(YOSYS_URL)"; \
	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
	else echo $$WGET_; $$WGET_; fi
	shasum -a 256 --check $(YOSYS_SHA)

# Clean build products but leave download cache alone
.PHONY: clean
clean:
	rm -rf build

# Clean everything
.PHONY: dist-clean
dist-clean:
	rm -rf build cache
