module core.hw.input.key_input;

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
        keyinput = 0x1FF; // all released
    }

    Half keyinput;
    
    void update_key(DSKeyCode key, bool pressed) {
        keyinput[key] = pressed;
    }

    Byte read_KEYINPUT(int target_byte) {
        final switch (target_byte) {
            case 0: return cast(Byte) keyinput[0.. 7];
            case 1: return cast(Byte) keyinput[8..15];
        }
    }
}