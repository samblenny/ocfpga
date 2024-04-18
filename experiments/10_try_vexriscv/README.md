<!-- SPDX-License-Identifier: CC-BY-SA-4.0 OR MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 10 Try VexRiscv


## Goals:

1. Compile a [VexRiscv](https://github.com/SpinalHDL/VexRiscv) CPU from
   SpinalHDL to Verilog using scala.

2. Translate a Verilog VexRiscv CPU into an ECP5 bitstream with YosysHQ tools.

3. Write Verilog to wire the CPU up to an observable output: blink the LED,
   flip a GPIO pin, export a register to JTAG, or anything I can get working.

4. Write a C program, compile it, and run it on the CPU. Anything I can get
   working to produce observable output would be fine.


## Questions

Can I use Debian's [scala](https://packages.debian.org/bookworm/scala) package?
The [Debian wiki](https://wiki.debian.org/Scala) describes Debian's Scala as
"fairly outdated version". When I read about what's involved in installing an
up to date Scala, it sounds like something I'd rather not have to deal with.


## Results

1. I'm setting this aside for now. Not exactly a fail. Maybe call it strategic
   retreat? Life is short, and I don't want to deal with the Java build tooling
   that VexRiscv depends on (sbt by way of scala).


## Lab Notes

1. Install Debian scala package and clone the VexRiscv repo

    ```console
    $ sudo apt install scala
    $ cd ~/code
    $ git clone https://github.com/SpinalHDL/VexRiscv.git
    ```

2. Read about how to build VexRiscv...

   According to the
   [Dependencies](https://github.com/SpinalHDL/VexRiscv/blob/master/README.md#dependencies)
   section of the main VexRiscv readme, I need something called `sbt`. The
   readme suggests adding `repo.scala-sbt.org` as an apt source, but I'd really
   rather not.

   When I start reading the `scala-sbt.org` website to figure out who runs that
   repository, it talks about Java and gives testimonial quotes from people
   working at a telecom company, an energy company, and what appears to be a
   marketing analytics company.

   It's been a long time since I had to mess with corporate-style Java tooling.
   That stuff is a hassle. This is not looking encouraging.

3. Read more about sbt...

   This is rapidly taking me down a rabbit hole of links to pages with stuff
   about JDK versions and jar files and Docker images with the wrong JRE
   version. Oh my... I don't want to deal with this.

4. Nope, nope, nope...

    ```console
    $ sudo apt remove scala
    $ sudo apt autoremove
    $ cd ~/code
    $ rm -rf VexRiscv
    ```

   I'm calling this experiment off for now. There are other open-licensed RV32
   CPU designs written in Verilog and SystemVerilog which should be easier to
   deal with. I should try building a different CPU.
