module emu.hw.input.key_input;

import util;

enum DSKeyCode {
    A      = 0,
    B      = 1,
    SELECT = 2,
    START  = 3,
    RIGHT  = 4,
    LEFT   = 5,
    UP     = 6,
    DOWN   = 7,
    R      = 8,
    L      = 9
}

__gshared KeyInput input;
final class KeyInput {
    this() {
        input = this;
        reset();
    }

    void reset() {
        keys = 0xCB01FF; // all released
    }

    Word keys;
    
    void update_key(DSKeyCode key, bool pressed) {
        keys[key] = !pressed;
    }

    Byte read_KEYINPUT(int target_byte) {
        return keys[0..15].get_byte(target_byte);
    }

    Byte read_EXTKEYIN(int target_byte) {
        return keys[16..31].get_byte(target_byte);
    }
}