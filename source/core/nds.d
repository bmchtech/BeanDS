module core.nds;

import core.hw.cpu;
import core.hw.memory;

import util;

final class NDS {
    Cart     cart;
    ARM7TDMI arm7;
    Mem7     mem7;

    this() {
        mem7 = new Mem7();
        arm7 = new ARM7TDMI(mem7);
    }

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
    }

    void direct_boot() {

    }
}