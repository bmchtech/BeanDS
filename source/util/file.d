module util.file;

import std.conv;

import util;

Byte[] load_file_as_bytes(string file_name) {
    import std.stdio;

    File file = File(file_name, "r");
    auto buffer = new ubyte[file.size()];
    file.rawRead(buffer);

    return to!(Byte[])(buffer);
}