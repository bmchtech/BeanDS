module emu.hw.nds;

import emu;

import ui.device;

import util;

final class NDS {
    Cart      cart;
    ARM7TDMI  arm7;
    ARM946E_S arm9;
    Mem7      mem7;
    Mem9      mem9;
    
    CpuTrace cpu_trace;

    this() {
        // TODO: find some way to standardize this global variable mess.
        //       either make everything a global variable
        //       or make nothing.
        new Scheduler();

        mem7 = new Mem7();
        mem9 = new Mem9();
        arm7 = new ARM7TDMI(mem7);
        arm9 = new ARM946E_S(mem9);

        cpu_trace = new CpuTrace(arm7, 100);

        InterruptManager.reset();
        IPC.reset();
        WRAM.reset();
        
        new SqrtController();
        new DivController();
        

        // TODO: maybe this doesnt belong in nds.d... i need to learn more
        //       about the two GBA engines to find out
        new GPU();
        new GPUEngineA();

        new KeyInput();
    }

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
    }

    void load_bios7(Byte[] bios) {
        mem7.load_bios(bios);
    }

    void load_bios9(Byte[] bios) {
        mem9.load_bios(bios);
    }

    void direct_boot() {
        if (cart.cart_header.arm7_rom_offset + cart.cart_header.arm7_size > cart.rom_size ||
            cart.cart_header.arm9_rom_offset + cart.cart_header.arm9_size > cart.rom_size) {
            error_nds("Malformed ROM - could not direct boot, cart.rom_size is too small. Are you sure the ROM is not corrupted?");
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
    
        mem9.skip_firmware();
        wram.skip_firmware();
    }

    void cycle() {
        arm7.run_instruction();
        arm9.run_instruction();
        arm9.run_instruction();
        scheduler.tick(4);
        scheduler.process_events();
    }

    void set_multimedia_device(MultiMediaDevice device) {
        gpu.set_present_videobuffer_callback(&device.present_videobuffer);
        device.set_update_key_callback(&input.update_key);
    }
}