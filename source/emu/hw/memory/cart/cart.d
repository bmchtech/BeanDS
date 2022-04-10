module emu.hw.memory.cart.cart;

import emu;
import util;

__gshared Cart cart;
final class Cart {
    CartHeader* cart_header;
    Byte[] rom;

    this(Byte[] rom) {
        cart = this;
        this.rom = new Byte[rom.length];
        this.rom[0..rom.length] = rom[0..rom.length];
        
        this.cart_header = get_cart_header(rom);
    }

    @property 
    size_t rom_size() {
        return rom.length;
    }

    T read(T)(Word address) {
        // log_cart("stuff: %x %x %x", address, rom.length, rom.read!T(address));
        if (address < rom_size()) {
            return rom.read!T(address);
        }

        error_cart("tried to read from cart at an out of range address: %x", address);
        return T(0);
    }
}