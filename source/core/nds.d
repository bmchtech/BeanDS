module core.nds;

import core.hw.memory.cart;

import util;

struct NDS {
    Cart* cart;

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
    }

    void direct_boot() {

    }
}