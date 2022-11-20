module emu.hw.memory.strategy.slowmem.pram;

import emu.hw.memory.strategy.common;
import emu.hw.memory.mem;
import util;

final class SlowMemPRAM {
    Byte[PRAM_SIZE] data;

    this() {
        this.data = new Byte[PRAM_SIZE];
    }

    T read(T)(Word address) {
        return data.read!T(address % PRAM_SIZE);
    }

    void write(T)(Word address, T value) {
        static if (is(T == Byte)) {
            log_vram("A CPU tried to perform a byte write of %02x to PRAM at address %08x! Ignoring.", value, address);
        }

        data.write!T(address % PRAM_SIZE, value);
    }
}