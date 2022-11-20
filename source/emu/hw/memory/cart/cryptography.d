module emu.hw.memory.cart.cryptography;

import emu.hw.memory.strategy.memstrategy;

import util;

final class Key1Encryption {
    enum KEYBUF_SIZE  = 0x412;
    enum KEYCODE_SIZE = 3;

    MemStrategy mem;

    u32[KEYBUF_SIZE]  keybuf;
    u32[KEYCODE_SIZE] keycode;

    this(MemStrategy mem) {
        this.mem = mem;

        keybuf  = new u32[KEYBUF_SIZE];
        keycode = new u32[KEYCODE_SIZE];
    }

    void encrypt_64bit(u32* val) {
        Word y = val[0];
        Word x = val[1];

        for (int i = 0; i < 16; i++) {
            Word z = keybuf[i] ^ x;
            x = keybuf[0x012 + z.get_byte(3)];
            x = keybuf[0x112 + z.get_byte(2)] + x;
            x = keybuf[0x212 + z.get_byte(1)] ^ x;
            x = keybuf[0x312 + z.get_byte(0)] + x;
            x = y ^ x;
            y = z;
        }

        val[0] = x ^ keybuf[16];
        val[1] = y ^ keybuf[17];
    }

    void decrypt_64bit(u32* val) {
        Word y = val[0];
        Word x = val[1];

        for (int i = 17; i >= 2; i--) {
            Word z = keybuf[i] ^ x;
            x = keybuf[0x012 + z.get_byte(3)];
            x = keybuf[0x112 + z.get_byte(2)] + x;
            x = keybuf[0x212 + z.get_byte(1)] ^ x;
            x = keybuf[0x312 + z.get_byte(0)] + x;
            x = y ^ x;
            y = z;
        }

        val[0] = x ^ keybuf[1];
        val[1] = y ^ keybuf[0];
    }

    void init_keycode(Word idcode, int level, int modulo) {
        for (int i = 0; i < KEYBUF_SIZE * 4; i++) {
            (cast(u8*) keybuf)[i] = mem.read_data_byte7(Word(0x30 + i));
        }

        keycode[0] = idcode;
        keycode[1] = idcode / 2;
        keycode[2] = idcode * 2;

        if (level >= 1) apply_keycode(modulo);
        if (level >= 2) apply_keycode(modulo);

        keycode[1] *= 2;
        keycode[2] /= 2;

        if (level >= 3) apply_keycode(modulo);
    }


    void apply_keycode(int modulo) {
        import core.bitop;

        encrypt_64bit(&keycode[1]);
        encrypt_64bit(&keycode[0]);
        u32[2] scratch = [0, 0];

        for (int i = 0; i < 0x48; i += 4) {
            keybuf[i / 4] = keybuf[i / 4] ^ bswap(keycode[(i % modulo) / 4]);
        }

        for (int i = 0; i < KEYBUF_SIZE * 4; i += 8) {
            encrypt_64bit(cast(u32*) scratch);
            keybuf[i / 4 + 0] = scratch[1];
            keybuf[i / 4 + 1] = scratch[0];
        }
    }
}