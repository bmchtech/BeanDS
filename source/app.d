import std.stdio;

void main(string[] args) {
	import ui.cli;
	auto cli_args = parse_cli_args(args);

	import std.stdio;
	writefln("%s", cli_args);
}