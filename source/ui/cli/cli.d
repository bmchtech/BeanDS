module ui.cli.cli;

import std.conv;

import commandr;

struct CLIArgs {
    string rom_path;
    uint arm7_ringbuffer_size;
    uint arm9_ringbuffer_size;
    uint screen_scale;
}

CLIArgs parse_cli_args(string[] args) {
	auto program = new Program("BeanDS", "0.1").summary("Nintendo DS Emulator")
		.add(new Argument("rom_path", "path to rom file"))
        .add(new Option("7", "arm7_ringbuffer_size", "the number of instructions to capture in the arm7 ring buffer (default: 100)").optional.defaultValue("100"))
        .add(new Option("9", "arm9_ringbuffer_size", "the number of instructions to capture in the arm9 ring buffer (default: 100)").optional.defaultValue("100"))
		.add(new Option("s", "screen_scale", "the screen scale (default: 1)").optional.defaultValue("1"))
        .parse(args);

    return CLIArgs(
        program.arg("rom_path"),
        to!int(program.option("arm7_ringbuffer_size")),
        to!int(program.option("arm9_ringbuffer_size")),
        to!int(program.option("screen_scale"))
    );
}
