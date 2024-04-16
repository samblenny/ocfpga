#!/usr/bin/perl
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright 2024 Sam Blenny
use v5.30;
use warnings;
use Digest::SHA qw(sha256_hex);

# Download OrangeCrab prebuilt firmware files from commit 70eaca4 of github
# repo: orangecrab-fpga/production-test-sw
#
# This script would be serious overkill just to download 3 files. But, my
# secondary goal here is to practice techniques that I will need later on when
# it comes time to automate considerably more complex workflows (e.g. install
# system packages, download and install EDA tools, download sources, build
# gateware, build libraries, etc).
#

# Data to generate firmware urls and verify expected SHA256 digests
my $DATA = {
    files => [
        {
            name => 'blink_fw.dfu',
            baseurl => 'https://raw.githubusercontent.com/orangecrab-fpga/production-test-sw/70eaca4e4ad43d82aa99c95e220bf1c68bfd5748/prebuilt/',
            sha2 => 'e4ae2fd9b9e758c37d4e7403de341f3b4aba60abcacb67a75c4bfb914c099bc8',
            size => 1592,
        },
        {
            name => 'foboot-v3.1-orangecrab-r0.2-85F.bit',
            baseurl => 'https://raw.githubusercontent.com/orangecrab-fpga/production-test-sw/70eaca4e4ad43d82aa99c95e220bf1c68bfd5748/prebuilt/',
            sha2 => '053044a54fdb6e9c92e4a6170f79a98a6c0f59f45eb8c84d710fd2b2d8afda55',
            size => 415247,
        },
        {
            name => 'orangecrab-reboot-85F.bit',
            baseurl => 'https://raw.githubusercontent.com/orangecrab-fpga/production-test-sw/70eaca4e4ad43d82aa99c95e220bf1c68bfd5748/prebuilt/',
            sha2 => '4c4fed24aa15554fad560e2ef46710f1963f11edb0fef503b52fb86e343402b9',
            size => 280518,
        },
        {
            name => 'orangecrab-test-85F.bit',
            baseurl => 'https://raw.githubusercontent.com/orangecrab-fpga/production-test-sw/70eaca4e4ad43d82aa99c95e220bf1c68bfd5748/prebuilt/',
            sha2 => '94f3ae522fbc39808c22068eb8730c9ecd8522dcc23eb9be2bedf590a888f5a0',
            size => 603620,
        },
        {
            # This is a combined Soc + CircuitPython image for OrangeCrab 25F
            name => 'combine.dfu',
            baseurl => 'https://raw.githubusercontent.com/orangecrab-fpga/orangecrab-examples/929cea3d7e4a538bcfd15ba487cd1dc8b165fee9/litex/',
            sha2 => 'e8f816283e946cc07f50a809a33899e9f2085c958854830d191e2bf595a5795e',
            size => 947364,
        },
    ],
    outDir => 'prebuilt',
    downloaders => {
        curl => "curl --fail --no-progress-meter -L -O --output-dir prebuilt",
        wget => "wget --no-verbose --directory-prefix=prebuilt",
    },
};


# === Subroutines ============================================================


# Pick a downloader: macOS may only have curl, Debian may only have wget
sub pickDownloader {
    for my $cmd (sort keys %{$DATA->{downloaders}}) {
        my $cmdIsInPATH = 0 == system("which $cmd > /dev/null");
        if ($cmdIsInPATH) {
            return $DATA->{downloaders}->{$cmd};
        }
    }
    undef;
}

# Download a file
sub download {
    my($downloader, $file) = @_;
    my $cmd = "$downloader $file->{baseurl}$file->{name}";
    say $cmd;
    system($cmd);
}

# Calculate SHA256 digest of file
sub digest {
    my($file) = @_;
    my $sha = Digest::SHA->new(256);
    $sha->addfile($file);
    $sha->hexdigest;
}


# === Main ===================================================================


# 1. Attempt to pick a downloader command that will work on the current OS.
my $downloader = pickDownloader();
if (not defined $downloader) {
    my $cmds = join ' ', sort keys %{$DATA->{downloaders}};
    die "Unable to download: can't find any of these in \$PATH: $cmds\n";
}

# 2. Download all the files listed in the $DATA dictionary up top
say "=== Downloading files ===";
my $dir = $DATA->{outDir};
mkdir $dir if not -d $dir;
for my $file (@{$DATA->{files}}) {
    my $name = $file->{name};
    if (-f "$dir/$name") {
        say " already have $name";
    } else {
        if(0 != download($downloader, $file)) {
            die "ERR: $name : download failed\n";
        }
        sleep(3);
    }
}

# 3. Validate size and SHA256 digest of downloaded files
say "=== Validating Downloads ===";
for my $file (@{$DATA->{files}}) {
    my $name = $file->{name};
    my $path = "$dir/$name";
    if (! -f $path) {
        die "ERR: $path : file is missing\n";
    }
    my %size = ( want => $file->{size}, got => (stat $path)[7] );
    if ($size{want} != $size{got}) {
        die "ERR: $path : wanted size $size{want}, got $size{got}\n";
    }
    my %sha2 = (want => $file->{sha2}, got => digest($path));
    if ($sha2{want} ne $sha2{got}) {
        die "ERR: $path : wanted SHA256 $sha2{want}, got $sha2{got}\n";
    }
    say " OK: $path";
}
