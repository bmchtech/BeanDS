module emu.hw.gpu.oam;

import emu.hw.memory.mem;
import util;

__gshared OAM oam;
final class OAM {
    enum OAM_SIZE = 1 << 11;
    Byte[OAM_SIZE] data;

    this() {
        data = new Byte[OAM_SIZE];
    }

    T read(T)(Word address) {
        return data.read!T(address % OAM_SIZE);
    }

    void write(T)(Word address, T value) {
        static if (is(T == Byte)) {
            log_vram("A CPU tried to perform a byte write of %02x to OAM at address %08x! Ignoring.", value, address);
        }

        data.write!T(address % OAM_SIZE, value);
    }
}