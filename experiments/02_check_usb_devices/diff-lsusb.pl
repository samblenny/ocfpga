#!/usr/bin/perl
use v5.30;
use warnings;
use File::Temp qw(tempfile);
use IO::Handle;   # provides ->flush
use List::Util qw(uniq);

# This script guides you through the process of diffing lsusb output to
# detect which USB devices appear when you plug in an OrangeCrab. Expected
# behavior is that a DFU device will show up when you hold down btn0 while
# plugging in the USB cable. With the factory gateware loaded, the DFU
# device does not show up if you just plug in the cable without holding
# down btn0. But, it's possible to flash gateware that provides other USB
# device configurations.

die "This script only works on linux (needs lsusb)\n" if ($^O ne 'linux');

# Display an interactive prompt
sub prompt {
    my $message = shift;
    print "$message\npress Enter when ready...\n> ";
    <>;
}

# Extract list of unique USB device vendor:product IDs from string argument
sub extractIDs {
    my $diffString = shift;
    my $vendProdRE = qr/[[:xdigit:]]{4}:[[:xdigit:]]{4}/;
    my @vendorProductIDs =
        uniq map { /($vendProdRE)/; lc $1; }
        grep { /$vendProdRE/ }
        split /\n/, $diffString;
    @vendorProductIDs;
}

# Print a verbose lsusb for each of the vendor:product ID arguments
sub printVerboseLsusb {
    my @vendorProductIDs = @_;
    for (@vendorProductIDs) {
        print "=== lsusb -v -d $_ ===\n";
        print `lsusb -v -d $_`;
        print "===============================\n";
    }
}

# Make temporary files to hold the 3 sets of lsusb output
my($fh1, $tmpUnplugged) = tempfile();
my($fh2, $tmpNormal)    = tempfile();
my($fh3, $tmpHoldBtn0)  = tempfile();
my @tempFiles = ($tmpUnplugged, $tmpNormal, $tmpHoldBtn0);

# Capture baseline lsusb output with OrangeCrab unplugged
prompt("Baseline lsusb: Make sure OrangeCrab USB cable is disconnected.");
print $fh1 `lsusb`;
$fh1->flush;

# Diff baseline against lsusb for OrangeCrab plugged in normally
prompt("Normal lsusb: Connect OrangeCrab USB cable. (do not press btn0)");
print $fh2 `lsusb`;
$fh2->flush;
my $diffNormal = `diff $tmpUnplugged $tmpNormal`;
say "=== lsusb diff of baseline vs. lsusb plugged in normally ===";
print $diffNormal;
say "============================================================\n";
STDOUT->flush;
printVerboseLsusb( extractIDs($diffNormal) );

# Diff baseline against lsusb plugged in while holding btn0 down
prompt("disconnect  OrangeCrab USB cable.");
prompt("btn0 lsusb: connect OrangeCrab USB cable while pressing btn0.");
print $fh3 `lsusb`;
$fh3->flush;
my $diffBtn0   = `diff $tmpUnplugged $tmpHoldBtn0`;
say "=== lsusb diff of baseline vs. plugged in while holding btn0 ===";
print $diffBtn0;
say "================================================================\n";
printVerboseLsusb( extractIDs($diffBtn0) );

# Delete the temporary files
unlink @tempFiles;

__END__

$ ./diff-lsusb.pl
Baseline lsusb: Make sure OrangeCrab USB cable is disconnected.
press Enter when ready...
>
Normal lsusb: Connect OrangeCrab USB cable. (do not press btn0)
press Enter when ready...
>
=== lsusb diff of baseline vs. lsusb plugged in normally ===
============================================================

disconnect  OrangeCrab USB cable.
press Enter when ready...
>
btn0 lsusb: connect OrangeCrab USB cable while pressing btn0.
press Enter when ready...
>
=== lsusb diff of baseline vs. plugged in while holding btn0 ===
4a5
> Bus 001 Device 015: ID 1209:5af0 Generic OrangeCrab r0.2 DFU Bootloader v3.1-6-g62e92e2
================================================================

=== lsusb -v -d 1209:5af0 ===
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
===============================
