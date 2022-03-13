import std.stdio;

import core.nds;

import util;

void main(string[] args) {
	import ui.cli;
	auto cli_args = parse_cli_args(args);

	new NDS().load_rom(load_file_as_bytes(cli_args.rom_path));
}