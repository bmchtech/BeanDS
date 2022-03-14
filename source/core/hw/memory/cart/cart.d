module core.hw.memory.cart.cart;

import core.hw.memory.cart;
import util;

final class Cart {
    CartHeader* cart_header;
    Byte[] rom;

    this(Byte[] rom) {
        this.rom = new Byte[rom.length];
        this.rom[0..rom.length] = rom[0..rom.length];
        
        this.cart_header = get_cart_header(rom);
    }

    @property 
    size_t rom_size() {
        return rom.length;
    }
}