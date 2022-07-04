module emu.hw.memory.main_memory;

import emu;
import util;

__gshared MainMemory main_memory;

final class MainMemory {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] data;

    T read(T)(Word address) {
        return data.read!T(address & (MAIN_MEMORY_SIZE - 1));
    }

    void write(T)(Word address, T value) {
        data.write!T(address & (MAIN_MEMORY_SIZE - 1), value);
    }
}