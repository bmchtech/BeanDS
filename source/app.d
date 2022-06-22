import emu.hw.nds;

import ui;

import util;

version (gperf) {
	import gperftools_d.profiler;
}

version (unittest) {
} else {
	void main(string[] args) {
		auto cli_args = parse_cli_args(args);

		auto reng = new RengMultimediaDevice(1);

		auto nds = new NDS(cli_args.arm7_ringbuffer_size, cli_args.arm9_ringbuffer_size);
		nds.set_multimedia_device(reng);

		// sure i could put the bios in the cli_args... and i *will*
		// but right now, im dev'ing the emu, and i dont want to have
		// to keep typing the bios paths every time i run it. so,
		// shoot me, but im hardcoding it for now.
		nds.load_bios7(load_file_as_bytes("roms/biosnds7.rom"));
		nds.load_bios9(load_file_as_bytes("roms/biosnds9.rom"));
		nds.load_rom(load_file_as_bytes(cli_args.rom_path));
		nds.set_sample_rate(48000);
		nds.direct_boot();

		import std.stdio;
		version (gperf) {
			writefln("Started profiler");
			ProfilerStart();
		}

		new Runner(nds, 1, reng).run();

		version (gperf) {
			ProfilerStop();
			writefln("Ended profiler");
		}
	}
}