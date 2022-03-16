import std.stdio;

import core.hw.nds;

import ui;

import util;

void main(string[] args) {
	auto cli_args = parse_cli_args(args);

	auto nds = new NDS();
	nds.load_rom(load_file_as_bytes(cli_args.rom_path));
	nds.direct_boot();

	auto reng = new RengMultimediaDevice(1);
	new Runner(nds, 1, reng).run();
}