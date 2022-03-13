module core.hw.memory.mem;

import util;

enum AccessType {
    NONSEQUENTIAL,
    SEQUENTIAL
}

auto get_region(Word address) {
    return address[24..27];
}

pragma(inline, true)
T read(T)(Byte[] memory, Word address) {
    return *(cast(T*) memory[address >> T.sizeof]);
}

pragma(inline, true)
void write(T)(Byte[] memory, Word address, T value) {
    *(cast(T*) memory[address >> T.sizeof]) = value;
}