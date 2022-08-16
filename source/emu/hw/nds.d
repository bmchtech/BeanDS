module emu.hw.nds;

import std.mmfile;

import emu;

import ui.device;

import util;

enum HwType {
    NDS7,
    NDS9
}

__gshared NDS nds;
final class NDS {
    CpuTrace cpu_trace;

    bool booted = false;

    void delegate(Pixel[32][32]) update_icon;
    void delegate(string) update_rom_title;

    this(uint arm7_ringbuffer_size, uint arm9_ringbuffer_size) {
        // TODO: find some way to standardize this global variable mess.
        //       either make everything a global variable
        //       or make nothing.
        new Scheduler();

        mem7 = new Mem7();
        mem9 = new Mem9();
        arm7 = new ARM7TDMI(mem7, arm7_ringbuffer_size);
        arm9 = new ARM946E_S(mem9, arm9_ringbuffer_size);

        interrupt7 = new InterruptManager(arm7);
        interrupt9 = new InterruptManager(arm9);

        ipc7 = new IPC(interrupt7);
        ipc9 = new IPC(interrupt9);
        ipc7.set_remote(ipc9);
        ipc9.set_remote(ipc7);

        wram = new WRAM();
        timers7 = new TimerManager(interrupt7);
        timers9 = new TimerManager(interrupt9);
        spi = new SPI();
        auxspi = new AUXSPI();
        spu = new SPU();
        sound_capture = new SoundCapture();
        slot = new Slot();

        cpu_trace = new CpuTrace(arm7, 100);
        
        math_sqrt = new SqrtController();
        math_div = new DivController();

        mmio7 = new MMIO!mmio7_registers("MMIO7");
        mmio9 = new MMIO!mmio9_registers("MMIO9");
        dma7 = new DMA!(HwType.NDS7)();
        dma9 = new DMA!(HwType.NDS9)();

        // TODO: maybe this doesnt belong in nds.d... i need to learn more
        //       about the two GBA engines to find out
        gpu = new GPU();
        gpu_engine_a = new GPUEngineA();
        gpu_engine_b = new GPUEngineB();
        gpu3d = new GPU3D();

        input = new KeyInput();
        main_memory = new MainMemory();

        sio = new SIO();
        rtc_hook = new RTCHook();

        nds = this;
    }

    void reset() {
        spu.reset();
        slot.reset();
        spi.reset();

        arm7.reset();
        arm9.reset();
        cart.reset();

        rtc_hook.reset();
    }

    void reset_firmware() {
        // https://melonds.kuribo64.net/board/thread.php?pid=3322
        rtc_hook.set_time_lost(true);
    }

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
        
        if (cart.cart_header.rom_header_size >= cart.rom_size()) {
            error_nds("Malformed ROM - the specified rom header size is greater than the rom size.");
        }

        mem9.memcpy(Word(0x27FFE00), &cart.rom[0], cart.cart_header.rom_header_size);

        update_icon(
            cart.get_icon()
        );

        update_rom_title(
            cart.get_rom_title(FirmwareLanguage.ENGLISH)
        );
    }

    void load_bios7(Byte[] data) {
        mem7.load_bios(data);
    }

    void load_bios9(Byte[] data) {
        mem9.load_bios(data);
    }

    void load_firmware(Byte[] data) {
        firmware.load_firmware(data);
    }

    void direct_boot() {
        firmware.direct_boot();
        touchscreen.direct_boot();
        arm7.direct_boot();
        arm9.direct_boot();
        wram.direct_boot();

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
        
        cart.direct_boot();

        arm7.set_reg(pc, cart.cart_header.arm7_entry_address);
        arm9.set_reg(pc, cart.cart_header.arm9_entry_address);
        arm7.set_cpsr(arm7.get_cpsr | (1 << 7));
        arm9.set_cpsr(arm7.get_cpsr | (1 << 7));

        booted = true;
    }

    void cycle(int num_cycles) {
        auto target_timestamp = scheduler.get_current_time_relative_to_cpu() + num_cycles;

        while (scheduler.get_current_time_relative_to_cpu() < target_timestamp) {
            arm7.run_instruction();
            arm9.run_instruction();
            arm9.run_instruction();
            scheduler.tick(1);
            scheduler.process_events();
        }

        while (arm7.halted && arm9.halted) {
            scheduler.tick_to_next_event();
            scheduler.process_events();
        }
    }

    void set_multimedia_device(MultiMediaDevice device) {
        gpu.set_present_videobuffers_callback(&device.present_videobuffers);
        device.set_update_key_callback(&input.update_key);
        device.set_update_touchscreen_position(&touchscreen.update_touchscreen_position);
        spu.set_push_sample_callback(&device.push_sample);
        this.update_icon = &device.update_icon;
        this.update_rom_title = &device.update_rom_title;
    }

    void set_sample_rate(int sample_rate) {
        spu.set_cycles_per_sample(33_513_982 / sample_rate);
    }

    int get_backup_size() {
        // lol, fix this later
        return 32 * 256;
    }

    void load_save_mmfile(MmFile save_mmfile) {
        auxspi.eeprom.set_save_mmfile(save_mmfile);
    }

    void write_HALTCNT(int target_byte, Byte data) {
        final switch (data[6..7]) {
            case 0: break;
            case 1: error_nds("tried to enable GBA mode"); break;
            case 2: arm7.halt(); break;
            case 3: error_nds("tried to sleep"); break;
        }
    }

    Byte read_HALTCNT(int target_byte) {
        // TODO: whats the point of this useless read
        return Byte(0);
    }

    void write_POSTFLG(int target_byte, Byte data) {
        // currently i cannot differentiate and know which CPU issues this write.
        // so i will have to do this funny workaround:
        if (target_byte == 0 && (arm7.regs[pc] >> 16 == 0 || arm9.regs[pc] >> 16 == 0xFFFF)) {
            booted = data[0];
        }
    }

    Byte read_POSTFLG(int target_byte) {
        return target_byte == 0 ? Byte(booted) : Byte(0);
    }
}