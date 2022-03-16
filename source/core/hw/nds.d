module core.hw.nds;

import core.hw;
import core.scheduler;

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

        // TODO: find some way to standardize this global variable mess.
        //       either make everything a global variable
        //       or make nothing.
        new Scheduler();

        // TODO: maybe this doesnt belong in nds.d... i need to learn more
        //       about the two GBA engines to find out
        new GPU();
        new GPUEngineA();
    }

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
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

        arm7.set_reg(pc, cart.cart_header.arm7_entry_address);
        arm9.set_reg(pc, cart.cart_header.arm9_entry_address);
    }

    void cycle() {
        // arm7.run_instruction();
        arm9.run_instruction();
        arm9.run_instruction();
        scheduler.process_events();
    }
}