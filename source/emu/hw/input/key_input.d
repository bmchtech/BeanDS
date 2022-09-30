module emu.hw.input.key_input;

import emu;
import util;

enum DSKeyCode {
    A        = 0,
    B        = 1,
    SELECT   = 2,
    START    = 3,
    RIGHT    = 4,
    LEFT     = 5,
    UP       = 6,
    DOWN     = 7,
    R        = 8,
    L        = 9,
    X        = 16,
    Y        = 17,
    PEN_DOWN = 22
}

__gshared bool verbosity = false;

__gshared KeyInput input;
final class KeyInput {
    void reset() {
        keys = 0x007F01FF; // all released
    }

    Word keys;
    
    void update_key(DSKeyCode key, bool pressed) {
        keys[key] = !pressed;
    }

    Byte read_KEYINPUT(int target_byte) {
        arm9.num_log = 1;
        
        for (int i = 0; i < 64; i++) {
            log_arm9("stack contents: [%x] = %x", arm9.regs[sp] + i * 4, mem9.read!Word(arm9.regs[sp] + i * 4));
        }

        return keys[0..15].get_byte(target_byte);
    }

    Byte read_EXTKEYIN(int target_byte) {
        return keys[16..31].get_byte(target_byte);
    }
}