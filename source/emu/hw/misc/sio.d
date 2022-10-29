module emu.hw.misc.sio;

import util;

__gshared SIO sio;
final class SIO {
    Half rcnt;

    Byte read_RCNT(int target_byte) {
        return rcnt.get_byte(target_byte);
    }

    void write_RCNT(int target_byte, Byte value) {
        rcnt.set_byte(target_byte, value);
        rcnt &= 0xE1FF; // force clear bits 9-13
    }
}