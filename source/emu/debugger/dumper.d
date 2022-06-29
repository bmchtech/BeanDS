module emu.debugger.dumper;

import util;

void dump(Byte[] data, string file_name) {
    import std.file;
    import std.stdio;

    auto f = File(file_name, "w+");
    f.rawWrite(cast(byte[]) data);
    f.close();
}