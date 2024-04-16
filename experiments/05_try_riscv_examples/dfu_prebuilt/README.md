# RISCV Examples

This directory has prebuilt binaries from my fork of the
orangecrab-fpga/orangcrab-examples repo on Github.
- Upstream:
  [orangecrab-examples/riscv/](https://github.com/orangecrab-fpga/orangecrab-examples/tree/main/riscv)
- My fork with modifications to build on Orangecrab 85F:
  [orangecrab-examples/riscv/](https://github.com/samblenny/orangecrab-examples/tree/553d17b381ecdc8c882a3bed50b4694257da4bdf/riscv)


Prebuilt Binaries:
- [blink_85F.dfu](blink_85F.dfu): makes the RGB LED blink cyan
- [button_85F.dfu](button_85F.dfu): makes the LED cycle through red, greeen,
  and blue as you press the btn0 button

It should be possible to load either of those binaries to an 85F board with
```bash
$ dfu-util -d 1209:5af0 --alt 0 -D $THE_DFU_FILE
```

These files won't work on an OrangeCrab 25F unless you first use `dfu-suffix`
to change the product ID suffix.


## Example Code License & Copyright

The examples are copyright 2020 Gregory Davill, with an MIT license. For a copy
of the copyright and license notice, see
[LICENSE_orangecrab-examples](LICENSE_orangecrab-examples)
