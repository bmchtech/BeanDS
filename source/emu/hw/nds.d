module emu.hw.nds;

// TODO: this import-spam needs to be fixed. in order to do that, i'll have to
// offload the construction of the NDS state to each of the components instead.
import emu.debugger.cputrace;
import emu.hw.cpu.arm7tdmi;
import emu.hw.cpu.arm946e_s;
import emu.hw.cpu.armcpu;
import emu.hw.cpu.interrupt;
import emu.hw.cpu.ipc;
import emu.hw.gpu.engines.engine_a;
import emu.hw.gpu.engines.engine_b;
import emu.hw.gpu.gpu;
import emu.hw.gpu.gpu3d;
import emu.hw.gpu.pixel;
import emu.hw.hwtype;
import emu.hw.input;
import emu.hw.math.division;
import emu.hw.math.sqrt;
import emu.hw.memory.cart;
import emu.hw.memory.dma;
import emu.hw.memory.main_memory;
import emu.hw.memory.mem7;
import emu.hw.memory.mem9;
import emu.hw.memory.mmio;
import emu.hw.memory.slot;
import emu.hw.memory.strategy.memstrategy;
import emu.hw.memory.wram;
import emu.hw.misc.rtc;
import emu.hw.misc.sio;
import emu.hw.spi.auxspi;
import emu.hw.spi.device.firmware;
import emu.hw.spi.device.touchscreen;
import emu.hw.spi.spi;
import emu.hw.spu.capture;
import emu.hw.spu.spu;
import emu.hw.timers;
import emu.scheduler;
import std.mmfile;
import ui.device;
import util;

__gshared NDS nds;
final class NDS {
    CpuTrace cpu_trace;

    bool booted = false;

    void delegate(Pixel[32][32]) update_icon;
    void delegate(string) update_rom_title;

    Mem mem;

    this(uint arm7_ringbuffer_size, uint arm9_ringbuffer_size) {
        // TODO: find some way to standardize this global variable mess.
        //       either make everything a global variable
        //       or make nothing.
        new Scheduler();

        mem = new Mem();
        arm7 = new ARM7TDMI(mem, arm7_ringbuffer_size);
        arm9 = new ARM946E_S(mem, arm9_ringbuffer_size);

        interrupt7 = new InterruptManager(arm7);
        interrupt9 = new InterruptManager(arm9);

        ipc7 = new IPC(interrupt7);
        ipc9 = new IPC(interrupt9);
        ipc7.set_remote(ipc9);
        ipc9.set_remote(ipc7);

        wram = new WRAM(mem);
        timers7 = new TimerManager(interrupt7);
        timers9 = new TimerManager(interrupt9);
        spi = new SPI();
        auxspi = new AUXSPI();
        spu = new SPU(mem);
        sound_capture = new SoundCapture();
        slot = new Slot();

        cpu_trace = new CpuTrace(arm7, 100);
        
        math_sqrt = new SqrtController();
        math_div = new DivController();

        mmio7 = new MMIO!mmio7_registers("MMIO7");
        mmio9 = new MMIO!mmio9_registers("MMIO9");
        dma7 = new DMA!(HwType.NDS7)(mem);
        dma9 = new DMA!(HwType.NDS9)(mem);

        // TODO: maybe this doesnt belong in nds.d... i need to learn more
        //       about the two GBA engines to find out
        gpu = new GPU(mem);
        gpu_engine_a = new GPUEngineA(mem);
        gpu_engine_b = new GPUEngineB(mem);
        gpu3d = new GPU3D(mem);

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
        input.reset();

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
        cart = new Cart(mem, rom);
        
        if (cart.cart_header.rom_header_size >= cart.rom_size()) {
            error_nds("Malformed ROM - the specified rom header size is greater than the rom size.");
        }

        for (int i = 0; i < cart.cart_header.rom_header_size; i++) {
            mem.write_data_byte9(Word(0x027F_FE00 + i), cart.rom[i]);
        }

        update_icon(
            cart.get_icon()
        );

        update_rom_title(
            cart.get_rom_title(FirmwareLanguage.ENGLISH)
        );
    }

    void load_bios7(Byte[] data) {
        mem.load_bios7(data);
    }

    void load_bios9(Byte[] data) {
        mem.load_bios9(data);
    }

    void load_firmware(MmFile mm_file) {
        firmware.load_firmware(mm_file);
    }

    void direct_boot() {
        firmware.direct_boot();
        touchscreen.direct_boot();
        arm7.direct_boot();
        arm9.direct_boot();
        wram.direct_boot();
        spu.direct_boot();

        if (cart.cart_header.arm7_rom_offset + cart.cart_header.arm7_size > cart.rom_size ||
            cart.cart_header.arm9_rom_offset + cart.cart_header.arm9_size > cart.rom_size) {
            error_nds("Malformed ROM - could not direct boot, cart.rom_size is too small. Are you sure the ROM is not corrupted?");
        } 

        for (int i = 0; i < cart.cart_header.arm7_size; i++) {
            mem.write_data_byte7(Word(cart.cart_header.arm7_ram_address + i), cart.rom[cart.cart_header.arm7_rom_offset + i]);
        }

        for (int i = 0; i < cart.cart_header.arm9_size; i++) {
            mem.write_data_byte9(Word(cart.cart_header.arm9_ram_address + i), cart.rom[cart.cart_header.arm9_rom_offset + i]);
        }
        
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
            scheduler.tick(2);
            scheduler.process_events();

            while (arm7.halted && arm9.halted) {
                scheduler.tick_to_next_event();
                scheduler.process_events();
            }
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
        return 262144;
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

    Byte read_POSTFLG7(int target_byte) {
        return read_POSTFLG(target_byte);
    }

    Byte read_POSTFLG9(int target_byte) {
        return read_POSTFLG(target_byte);
    }

    void write_POSTFLG7(int target_byte, Byte data) {
        if (arm7.regs[pc] >> 16 == 0) {
            write_POSTFLG(target_byte, data);
        }
    }

    void write_POSTFLG9(int target_byte, Byte data) {
        if (arm9.regs[pc] >> 16 == 0xFFFF) {
            write_POSTFLG(target_byte, data);
        }
    }

    private void write_POSTFLG(int target_byte, Byte data) {
        if (target_byte == 0) {
            booted |= data[0];
        }
    }

    Byte read_POSTFLG(int target_byte) {
        return target_byte == 0 ? Byte(booted) : Byte(0);
    }

    Byte read_SM64_DSI_STUB(int target_byte) {
        return Word(0x8000).get_byte(target_byte);
    }
}