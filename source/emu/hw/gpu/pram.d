module emu.hw.gpu.pram;

import emu.hw;

import util;

__gshared PRAM pram;
final class PRAM {
    enum PRAM_SIZE  = 1 << 11;

    Byte[PRAM_SIZE] data = new Byte[PRAM_SIZE];

    this() {
        pram = this;
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