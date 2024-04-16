<!-- SPDX-License-Identifier: CC-BY-SA-4.0 or MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 02 Check USB Devices

Goal of this experiment is to identify which USB devices appear when you plug
in the OrangeCrab.


## Procedure:

I wrote an interactive script ([`diff-lsusb.pl`](diff-lsusb.pl)) to mostly
automate the process of taking diffs between three different invocations of
`lsusb`.

The script does the following stuff:

1. Prompts you to make sure the OrangeCrab is unplugged

2. Captures a baseline `lsusb` USB device listing (non-OrangeCrab devices)

3. Prompts you to plug in the Orange crab normally

4. Captures a new `lsbusb` and prints the diff against the baseline

5. Prints a verbose `lsusb` for each device appearing in the diff (with the
   factory firmware, this list should be empty)

6. Prompts you to unplug the OrangeCrab then plug it back in while holding
   down the OrangeCrab's `btn0` button (the incantation to invoke DFU mode)

7. Captures another `lsusb` and prints the diff against the baseline

8. Prints a verbose `lsusb` for each device appearing in the diff (with the
   factory firmware, this list should have one DFU device)


## Results:

1. No new USB devices when plugging in the cable normally

2. `1209:5af0 Generic OrangeCrab r0.2 DFU Bootloader v3.1-6-g62e92e2` appears
   when I plug the cable in while holding down the OrangeCrab's `btn0` button.


### Verbose `lsusb` output for vendor:product `1209:5af0`:

```
Couldn't open device, some information will be missing

Bus 001 Device 015: ID 1209:5af0 Generic OrangeCrab r0.2 DFU Bootloader v3.1-6-g62e92e2
Device Descriptor:
  bLength                18
  bDescriptorType         1
  bcdUSB               2.01
  bDeviceClass          239 Miscellaneous Device
  bDeviceSubClass         2
  bDeviceProtocol         1 Interface Association
  bMaxPacketSize0        64
  idVendor           0x1209 Generic
  idProduct          0x5af0
  bcdDevice            1.01
  iManufacturer           1 GsD
  iProduct                2 OrangeCrab r0.2 DFU Bootloader v3.1-6-g62e92e2
  iSerial                 0
  bNumConfigurations      1
  Configuration Descriptor:
    bLength                 9
    bDescriptorType         2
    wTotalLength       0x002d
    bNumInterfaces          1
    bConfigurationValue     1
    iConfiguration          1
    bmAttributes         0x80
      (Bus Powered)
    MaxPower              100mA
    Interface Descriptor:
      bLength                 9
      bDescriptorType         4
      bInterfaceNumber        0
      bAlternateSetting       0
      bNumEndpoints           0
      bInterfaceClass       254 Application Specific Interface
      bInterfaceSubClass      1 Device Firmware Update
      bInterfaceProtocol      2
      iInterface              3
      Device Firmware Upgrade Interface Descriptor:
        bLength                             9
        bDescriptorType                    33
        bmAttributes                       13
          Will Detach
          Manifestation Tolerant
          Upload Unsupported
          Download Supported
        wDetachTimeout                  10000 milliseconds
        wTransferSize                    4096 bytes
        bcdDFUVersion                   1.01
    Interface Descriptor:
      bLength                 9
      bDescriptorType         4
      bInterfaceNumber        0
      bAlternateSetting       1
      bNumEndpoints           0
      bInterfaceClass       254 Application Specific Interface
      bInterfaceSubClass      1 Device Firmware Update
      bInterfaceProtocol      2
      iInterface              4
      Device Firmware Upgrade Interface Descriptor:
        bLength                             9
        bDescriptorType                    33
        bmAttributes                       13
          Will Detach
          Manifestation Tolerant
          Upload Unsupported
          Download Supported
        wDetachTimeout                  10000 milliseconds
        wTransferSize                    4096 bytes
        bcdDFUVersion                   1.01
```
