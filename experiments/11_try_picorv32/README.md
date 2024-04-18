<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 11 Try PicoRV32


## Goals:

1. Translate a [PicoRV32](https://github.com/YosysHQ/picorv32) CPU from
   Verilog into an ECP5 bitstream with YosysHQ tools.

2. Write Verilog to wire the CPU up to an observable output: blink the LED,
   flip a GPIO pin, export a register to JTAG, or anything I can get working.

3. Write a C program, compile it, and run it on the CPU. Anything I can get
   working to produce observable output would be fine.


## Results

*work in progress*

1. ...


## Lab Notes

1. Clone repo and check out
   [commit 336cfca](https://github.com/YosysHQ/picorv32/tree/336cfca6e5f1c08788348aadc46b3581b9a5d585)
   (current head of main on April 18, 2024)...

    ```console
    $ cd ~/code
    $ git clone https://github.com/YosysHQ/picorv32.git
    ...
    $ cd picorv32
    $ git checkout -b 2024-04-18 336cfca6e5f1c08788348aadc46b3581b9a5d585
    Switched to a new branch '2024-04-18'
    ```
