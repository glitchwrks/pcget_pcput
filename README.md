# PCGET and PCPUT

`PCGET` and `PCPUT` are a pair of CP/M-80 programs used to do `XMODEM` transfers to and from CP/M machines, presumably to modern PCs, usually over the console serial port.

### Building

This project requires the [Glitch Works](http://www.glitchwrks.com/) modified version of the `A85` assembler to be compiled and available on your `$PATH`. `A85` can be found [in our GitHub repository](https://github.com/glitchwrks/a85/).

Machine-specific implementations can be built by assembling their respective `PCGET.ASM` or `PCPUT.ASM`.

### History

[Mike Douglas](http://deramp.com/) started releasing a number of `PCGET` and `PCPUT` implementation as a simple way to get files to and from vintage computers, when using another computer with a terminal emulator as the console port. His work is based on [Ward Christensen's](https://en.wikipedia.org/wiki/Ward_Christensen) [XMODEM](https://en.wikipedia.org/wiki/XMODEM) implementation as found in CP/M `MODEM` programs. Most of the work in this repository dates back to his 2015-10-07 version for the North Star Horizon, which itself was based on his version for the Vector Graphic.