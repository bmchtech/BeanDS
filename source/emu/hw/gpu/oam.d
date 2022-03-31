module emu.hw.gpu.oam;

import emu;
import util;

__gshared OAM oam;
final class OAM {
    enum OAM_SIZE = 1 << 11;
    Byte[OAM_SIZE] data;

    private this() {
        data = new Byte[OAM_SIZE];
    }

    static void reset() {
        oam = new OAM();
    }

    T read(T)(Word address) {
        return data.read!T(address % OAM_SIZE);
    }

    void write(T)(Word address, T value) {
        data.write!T(address % OAM_SIZE, value);
    }
}