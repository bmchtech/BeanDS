module core.hw.memory.cart.cart;

import core.hw.memory.cart;
import util;

final class Cart {
    CartHeader* cart_header;
    Byte[] rom;

    this(Byte[] rom) {
        this.rom = rom;
        this.cart_header = get_cart_header(rom);
    }
}