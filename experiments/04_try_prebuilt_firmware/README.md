# 04 Try Prebuilt Firmware

Work in progress. See [download-firmware.pl](download-firmware.pl).

Next steps:

1. What linux program do I use to talk to the DFU device?

2. Is it possible to read current factory LED blinking firmware over DFU? Can I
   compare a digest of that to the prebuilt `blink_fw.dfu` file?

3. Can I flash `orangecrab-reboot-85F.bit` and `orangecrab-test-85F.bit` over
   DFU, or do those need JTAG?

4. What about https://github.com/orangecrab-fpga/orangecrab-examples ?
