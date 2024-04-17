# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
#
# Download and build yosys, nexpnr, ecppack, and ecpunpack to ~/bin/
#
.POSIX:

# Default install prefix for built tools
PREFIX ?= $(HOME)/bin

# Download cache filepaths for source archives
YOSYS_TAR = cache/yosys-0.40.tar.gz
NEXTPNR_TAR = cache/nextpnr-0.7.tar.gz
TRELLIS_TAR = cache/prjtrellis-1.4.tar.gz

# Source archive URLs
YOSYS_URL   = https://github.com/YosysHQ/yosys/archive/refs/tags/yosys-0.40.tar.gz
NEXTPNR_URL = https://github.com/YosysHQ/nextpnr/archive/refs/tags/nextpnr-0.7.tar.gz
TRELLIS_URL = https://github.com/YosysHQ/prjtrellis/archive/refs/tags/1.4.tar.gz

# Expected SHA256 digests for source tarballs
SHA256 = src_tarballs.SHA256

# Downloaders
CURL = curl --fail -L -o
WGET = wget --no-verbose -O

# Build directories (unpacked from tarballs)
YOSYS_B = build/yosys-yosys-0.40
NEXTPNR_B = build/nextpnr-nextpnr-0.7
TRELLIS_B = build/prjtrellis-1.4

# nextpnr build dependencies (.deb packages for Debian or Ubuntu)
NEXTPNR_DEPS = cmake clang python3-dev libboost-all-dev libeigen3-dev


# Default target is usage message
all:
	@echo "available targets: get-src unpack-src clean dist-clean"

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
		then echo SUCCESS! Build dependencies are installed; \
		else echo ERROR: you need to install missing packages; \
			echo "  try 'sudo apt install $$MISSING_DEPS'"; \
			false; \
	fi

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

# Download nextpnr tarball to cache using curl or wget
$(NEXTPNR_TAR):
	@mkdir -p cache
	@CURL_="$(CURL) $(NEXTPNR_TAR) $(NEXTPNR_URL)"; \
	WGET_="$(WGET) $(NEXTPNR_TAR) $(NEXTPNR_URL)"; \
	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
	else echo $$WGET_; $$WGET_; fi

# Download prjtrellis tarball to cache using curl or wget
$(TRELLIS_TAR):
	@mkdir -p cache
	@CURL_="$(CURL) $(TRELLIS_TAR) $(TRELLIS_URL)"; \
	WGET_="$(WGET) $(TRELLIS_TAR) $(TRELLIS_URL)"; \
	if which curl >/dev/null; then echo $$CURL_; $$CURL_; \
	else echo $$WGET_; $$WGET_; fi

# Clean up
clean:
	rm -rf build
dist-clean:
	rm -rf build cache

.PHONY: all get-src unpack-src check-deps clean dist-clean
