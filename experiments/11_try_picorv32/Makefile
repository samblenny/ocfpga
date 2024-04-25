# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
.POSIX:

.PHONY: all
all:
	@echo 'Available make targets:'
	@echo ''
	@echo 'flash-pullup'
	@echo '  Build and flash pullup.bit using openFPGALoader + Tigard JTAG'
	@echo ''
	@echo 'screen'
	@echo '  Start 19200 baud screen terminal emulator using Tigard UART'
	@echo 'pullup.lpf'
	@echo '  Generate lpf file for putting a pullup on SDA (uses gen_lpf.py)'
	@echo ''
	@echo 'triple-check-report.txt'
	@echo '  Compare output of gen_lpf.py with orangecrab_r0.2.1.pcf'
	@echo ''
	@echo 'pullup.bit'
	@echo '  Build ECP5 bitstream to put pullup on SDA:'
	@echo ''

# Flash pullup bitstream via Tigard JTAG, rebuilding bitstream if needed
.PHONY: flash-pullup
flash-pullup: pullup.bit
	openFPGALoader -c tigard --freq 1M \
		-f --file-type raw --verify -o 0x80000 pullup.bit

# Start terminal emulator (screen) with Tigard at low-ish baud rate so serial
# monitor LED flashing will be slow enough to see clearly
.PHONY: screen
screen:
	@echo 'Starting terminal emulator (screen)...'
	@echo '  to quit screen, type: Ctrl-a k y'
	@echo ''
	@read -p 'type Enter to begin (remember: Ctrl-a k y) > ' REPLY
	screen -fn \
		/dev/serial/by-id/usb-SecuringHardware.com_Tigard_*-if00-port0 \
		19200

# Build bitstream with serial loopback, LED RX status, and I2C pullups
pullup.bit: pullup.lpf pullup.v
	yosys -p "read_verilog -sv -noautowire pullup.v; \
		synth_ecp5 -json pullup.json"
	nextpnr-ecp5 --json pullup.json --textcfg pullup_out.config \
		--85k --package CSFBGA285 --lpf pullup.lpf
	ecppack --compress --freq 38.8 --input pullup_out.config --bit pullup.bit
	rm -f pullup.json pullup_out.config

# Build pin constraint file with pullups on I2C SDA and SCL
pullup.lpf: gen_lpf.py
	python3 gen_lpf.py > pullup.lpf

# Build triple-check report
triple-check-report.txt: triple-check-lpf.py gen_lpf.py
	python3 triple-check-lpf.py > triple-check-report.txt

