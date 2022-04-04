import std.stdio;

import emu.hw.nds;

import ui;

import util;

void main(string[] args) {
	auto cli_args = parse_cli_args(args);

	auto nds = new NDS();
	
	// sure i could put the bios in the cli_args... and i *will*
	// but right now, im dev'ing the emu, and i dont want to have
	// to keep typing the bios paths every time i run it. so,
	// shoot me, but im hardcoding it for now.
	nds.load_bios7(load_file_as_bytes("roms/biosnds7.rom"));
	nds.load_bios9(load_file_as_bytes("roms/biosnds9.rom"));
	nds.load_rom(load_file_as_bytes(cli_args.rom_path));
	nds.set_sample_rate(44100);
	nds.direct_boot();

	auto reng = new RengMultimediaDevice(1);
	nds.set_multimedia_device(reng);
	new Runner(nds, 1, reng).run();
}