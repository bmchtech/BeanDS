import emu.hw.nds;
import std.file;
import std.mmfile;
import std.path;
import ui;
import util;

enum DIRECT_BOOT = false;

version (gperf) {
	import gperftools_d.profiler;
}

version (unittest) {
} else {
	void main(string[] args) {
		auto cli_args = parse_cli_args(args);

		auto nds = new NDS(cli_args.arm7_ringbuffer_size, cli_args.arm9_ringbuffer_size);

		if (cli_args.test_ui) {
			auto reng = new RengMultimediaDevice(cli_args.screen_scale, show_full_ui);
		} else {
			auto show_full_ui = cli_args.detailed_ui;
			auto reng = new RengMultimediaDevice(cli_args.screen_scale, show_full_ui);
			nds.set_multimedia_device(reng);

			// sure i could put the bios in the cli_args... and i *will*
			// but right now, im dev'ing the emu, and i dont want to have
			// to keep typing the bios paths every time i run it. so,
			// shoot me, but im hardcoding it for now.
			nds.load_bios7(load_file_as_bytes("roms/biosnds7.rom"));
			nds.load_bios9(load_file_as_bytes("roms/biosnds9.rom"));
			nds.load_firmware(load_file_as_bytes("roms/firmware.rom"));
			nds.load_rom(load_file_as_bytes(cli_args.rom_path));

			auto save_path = cli_args.rom_path.stripExtension().setExtension(".bsv");
			if (!save_path.exists()) {
				for (int i = 0; i < nds.get_backup_size(); i++) {
					write(save_path, [0]);
				}
			}

			MmFile mm_file = new MmFile(save_path, MmFile.Mode.readWrite, nds.get_backup_size(), null, 0);
			nds.load_save_mmfile(mm_file);

			nds.set_sample_rate(48_000);

			nds.reset();
			if (cli_args.direct_boot) nds.direct_boot();
			if (cli_args.reset_firmware) nds.reset_firmware();
			
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
}