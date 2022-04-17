module emu.hw.spi.auxspi;

import util;

__gshared AUXSPI auxspi;

final class AUXSPI {
    private this () {}

    static void reset() {
        auxspi = new AUXSPI();
    }

    // i do not understand romctrl for now.
    // so let's start out with a very crude implementation.
    Word romctrl;

    void write_ROMCTRL(int target_byte, Byte value) {
        romctrl.set_byte(target_byte, value);
    }

    Byte read_ROMCTRL(int target_byte) {
        return romctrl.get_byte(target_byte);
    }
}