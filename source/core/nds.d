module core.nds;

import core.hw.cpu;
import core.hw.memory;

import util;

final class NDS {
    Cart      cart;
    ARM7TDMI  arm7;
    ARM946E_S arm9;
    Mem7      mem7;
    Mem9      mem9;

    this() {
        mem7 = new Mem7();
        mem9 = new Mem9();
        arm7 = new ARM7TDMI(mem7);
        arm9 = new ARM946E_S(mem9);
    }

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
        direct_boot();
    }

    void direct_boot() {
        if (cart.cart_header.arm7_rom_offset + cart.cart_header.arm7_size > cart.rom_size ||
            cart.cart_header.arm9_rom_offset + cart.cart_header.arm9_size > cart.rom_size) {
            error_memory("Malformed ROM - could not direct boot, cart.rom_size is too small. Are you sure the ROM is not corrupted?");
        } 

        mem7.memcpy(
            cart.cart_header.arm7_ram_address,
            &cart.rom[cart.cart_header.arm7_rom_offset],
            cart.cart_header.arm7_size
        );

        mem9.memcpy(
            cart.cart_header.arm9_ram_address,
            &cart.rom[cart.cart_header.arm9_rom_offset],
            cart.cart_header.arm9_size
        );
    }
}