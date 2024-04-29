# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
.POSIX:

.PHONY: all
all:
	@echo 'Available make targets:'
	@echo ''
	@echo 'flash-lowpower'
	@echo '  Build and flash lowpower.bit using openFPGALoader + Tigard JTAG'
	@echo ''
	@echo 'flash-pullup'
	@echo '  Build and flash pullup.bit using openFPGALoader + Tigard JTAG'
	@echo ''
	@echo 'flash-uart'
	@echo '  Build and flash uart.bit using openFPGALoader + Tigard JTAG'
	@echo ''
	@echo 'screen'
	@echo '  Start 19200 baud screen terminal emulator using Tigard UART'
	@echo ''
	@echo 'pullup.lpf'
	@echo '  Generate lpf file for putting a pullup on SDA (uses gen_lpf.py)'
	@echo ''
	@echo 'triple-check-report.txt'
	@echo '  Compare output of gen_lpf.py with orangecrab_r0.2.1.pcf'
	@echo ''
	@echo 'lowpower.bit'
	@echo '  Build ECP5 bitstream to configure OrangeCrab 85F for low power'
	@echo ''
	@echo 'pullup.bit'
	@echo '  Build ECP5 bitstream to put pullup on SDA'
	@echo ''
	@echo 'uart.bit'
	@echo '  Build ECP5 bitstream to send async serial on TX'
	@echo ''

# Flash lowpower bitstream via Tigard JTAG, rebuilding bitstream if needed
.PHONY: flash-lowpower
flash-lowpower: lowpower.bit
	openFPGALoader -c tigard --freq 1M \
		-f --file-type raw --verify -o 0x80000 lowpower.bit

# Flash pullup bitstream via Tigard JTAG, rebuilding bitstream if needed
.PHONY: flash-pullup
flash-pullup: pullup.bit
	openFPGALoader -c tigard --freq 1M \
		-f --file-type raw --verify -o 0x80000 pullup.bit

# Flash uart bitstream via Tigard JTAG, rebuilding bitstream if needed
.PHONY: flash-uart
flash-uart: uart.bit
	openFPGALoader -c tigard --freq 1M \
		-f --file-type raw --verify -o 0x80000 uart.bit

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

# Build bitstream for low power configuration
lowpower.bit: lowpower.lpf lowpower.v Makefile
	yosys -p "read_verilog -sv -noautowire lowpower.v; \
		synth_ecp5 -json lowpower.json"
	nextpnr-ecp5 --json lowpower.json --textcfg lowpower_out.config \
		--85k --package CSFBGA285 --lpf lowpower.lpf
	ecppack --compress --input lowpower_out.config --bit lowpower.bit
	rm -f lowpower.json lowpower_out.config

# Build bitstream with serial loopback, LED RX status, and I2C pullups
pullup.bit: pullup.lpf pullup.v Makefile
	yosys -p "read_verilog -sv -noautowire pullup.v; \
		synth_ecp5 -json pullup.json"
	nextpnr-ecp5 --json pullup.json --textcfg pullup_out.config \
		--85k --package CSFBGA285 --lpf pullup.lpf
	ecppack --compress --input pullup_out.config --bit pullup.bit
	rm -f pullup.json pullup_out.config

# Build bitstream with serial output on TX pin
uart.bit: lowpower.lpf uart.sv oc85f.sv Makefile
	yosys -p "read_verilog -sv -noautowire uart.sv oc85f.sv; \
		synth_ecp5 -json uart.json"
	nextpnr-ecp5 --json uart.json --textcfg uart_out.config \
		--85k --package CSFBGA285 --lpf lowpower.lpf
	ecppack --compress --input uart_out.config --bit uart.bit
	rm -f uart.json uart_out.config

# Build pin constraint file for low power configuration
lowpower.lpf: gen_lpf.py
	python3 gen_lpf.py > lowpower.lpf

# Build pin constraint file with pullups on I2C SDA and SCL
pullup.lpf: gen_lpf.py
	python3 gen_lpf.py > pullup.lpf

# Build triple-check report
triple-check-report.txt: triple-check-lpf.py gen_lpf.py gen_lpf.py
	python3 triple-check-lpf.py > triple-check-report.txt

