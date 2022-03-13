import std.stdio;

import core.hw.memory.cart;

void main(string[] args) {
	import ui.cli;
	auto cli_args = parse_cli_args(args);

	import std.stdio;
	import util;

	auto s = (new Cart(load_file_as_bytes(cli_args.rom_path)).cart_header.game_title);
	writefln("%x", s[0]);
	import std.conv;
	import std.format;
	writefln("%s", cast(char[]) s);
	error_memory("Attempt for ARM7 to access instruction TCM!");
}