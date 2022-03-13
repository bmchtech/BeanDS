module core.hw.memory.mem;

import util;

enum AccessType {
    NONSEQUENTIAL,
    SEQUENTIAL
}

abstract class Mem {
    void memcpy(Word address, Byte* source, size_t size) {
        for (int i = 0; i < size; i++) {
            this.write_byte(address + i, source[i]);
        }
    }

    abstract void write_word(Word address, Word value);
    abstract void write_half(Word address, Half value);
    abstract void write_byte(Word address, Byte value);
    abstract Word read_word(Word address);
    abstract Half read_half(Word address);
    abstract Byte read_byte(Word address);
}

auto get_region(Word address) {
    return address[24..27];
}

pragma(inline, true)
T read(T)(Byte[] memory, Word address) {
    return (cast(T*) memory)[address >> T.sizeof];
}

pragma(inline, true)
void write(T)(Byte[] memory, Word address, T value) {
    (cast(T*) memory)[address >> T.sizeof] = value;
}