module ui.cli;

import commandr;

struct CLIArgs {
    string rom_path;
}

CLIArgs parse_cli_args(string[] args) {
	auto program = new Program("BeanDS", "0.1").summary("Nintendo DS Emulator")
		.add(new Argument("rom_path", "path to rom file"))
		.parse(args);

    return CLIArgs(
        program.arg("rom_path")
    );
}
