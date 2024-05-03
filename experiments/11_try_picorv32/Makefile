# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
.POSIX:

.PHONY: all
all:
	@echo read Makefile to see available make targets

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

# Flash soc1 bitstream via Tigard JTAG, rebuilding bitstream if needed
.PHONY: flash-soc1
flash-soc1: soc1.bit
	openFPGALoader -c tigard --freq 2M \
		-f --file-type raw --verify -o 0x80000 soc1.bit

# Flash soc2 bitstream via Tigard JTAG, rebuilding bitstream if needed
.PHONY: flash-soc2
flash-soc2: soc2.bit
	openFPGALoader -c tigard --freq 2M \
		-f --file-type raw --verify -o 0x80000 soc2.bit

# Start terminal emulator (screen) with Tigard at low-ish baud rate so serial
# monitor LED flashing will be slow enough to see clearly
.PHONY: screen
screen:
#	@echo 'Starting terminal emulator (screen)...'
#	@echo '  to quit screen, type: Ctrl-a k y'
#	@echo ''
#	@read -p 'type Enter to begin (remember: Ctrl-a k y) > ' REPLY
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

# soc1: Build bitstream with serial loopback using full duplex wishbone UART
# This assumes https://github.com/YosysHQ/picorv32.git has been cloned into
# the parent same directory as ocfpga
PICORV32=../../../picorv32/picorv32.v
soc1.bit: lowpower.lpf soc1.sv uart1.sv $(PICORV32) Makefile
	yosys -p "read_verilog -sv -noautowire uart1.sv $(PICORV32) soc1.sv; \
		synth_ecp5 -json soc1.json"
	nextpnr-ecp5 --json soc1.json --textcfg soc1_out.config \
		--85k --package CSFBGA285 --lpf lowpower.lpf
	ecppack --compress --input soc1_out.config --bit soc1.bit
	rm -f soc1.json soc1_out.config

# soc2: Build bitstream with picorv
# (his depends on PICORV32=... which is defined above soc1)
soc2.bit: lowpower.lpf soc2.sv uart2.sv $(PICORV32) Makefile
	yosys -p "read_verilog -sv -noautowire uart2.sv $(PICORV32) soc2.sv; \
		synth_ecp5 -json soc2.json"
	nextpnr-ecp5 --json soc2.json --textcfg soc2_out.config \
		--85k --package CSFBGA285 --lpf lowpower.lpf
	ecppack --compress --input soc2_out.config --bit soc2.bit
	rm -f soc2.json soc2_out.config

# Build pin constraint file for low power configuration
lowpower.lpf: gen_lpf.py
	python3 gen_lpf.py > lowpower.lpf

# Build pin constraint file with pullups on I2C SDA and SCL
pullup.lpf: gen_lpf.py
	python3 gen_lpf.py > pullup.lpf

# Build triple-check report
triple-check-report.txt: triple-check-lpf.py gen_lpf.py gen_lpf.py
	python3 triple-check-lpf.py > triple-check-report.txt

