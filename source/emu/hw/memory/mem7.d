module emu.hw.memory.mem7;

import emu.hw.memory.mem;
import emu.hw.cpu.armcpu;
import emu.hw.memory.main_memory;
import emu.hw.memory.wram;
import emu.hw.memory.mmio;
import emu.hw.gpu.vram;
import emu.scheduler;

import util;

__gshared Mem7 mem7;
final class Mem7 : Mem {
    enum BIOS_SIZE = 1 << 14;
    Byte[BIOS_SIZE] bios = new Byte[BIOS_SIZE];

    this() {
        mem7 = this;
    }


    InstructionBlock* instruction_read(Word address) {
        scheduler.tick(1);

        auto region = get_region(address);

        if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to perform an instruction read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x0: .. case 0x1: return bios.instruction_read(address);
            case 0x2:              return main_memory.instruction_read(address);
            case 0x3:              return wram.instruction_read7(address);
            
            default: error_unimplemented("Attempt from ARM9 to perform an instruction read from an invalid region of memory: %x", address); break;
        }

        error_mem9("ARM7 instruction read from invalid address: %x", address);
        return null;
    }

    T read(T)(Word address) {
        scheduler.tick(1);

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x0: .. case 0x1: return bios.read!T(address);
            case 0x2:              return main_memory.read!T(address);
            case 0x3:              return wram.read7!T(address);
            case 0x4:              return mmio7.read!T(address);
            case 0x6:              return vram.read7!T(address);
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM7 to read from GBA Slot ROM: %x", address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM7 to read from GBA Slot RAM: %x", address); break;
            
            default: log_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address); break;
        }

        // should never happen
        // assert(0);
        return T();
    }

    void write(T)(Word address, T value) {
        scheduler.tick(1);

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to write %x to an invalid region of memory: %x", value, address);

        switch (region) {
            case 0x0: .. case 0x1: log_mem7("Attempt from ARM7 to write %x to BIOS: %x", value, address); break;
            case 0x2:              main_memory.write!T(address, value); break;
            case 0x3:              wram.write7!T(address, value); break;
            case 0x4:              mmio7.write!T(address, value); break;
            case 0x6:              vram.write7!T(address, value); break;
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM7 to write %x to GBA Slot ROM: %x", value, address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM7 to write %x to GBA Slot RAM: %x", value, address); break;

            default: log_unimplemented("Attempt from ARM7 to write %x to an invalid region of memory: %x", value, address); break;
        }
    }

    void load_bios(Byte[] bios) {
        this.bios[0..BIOS_SIZE] = bios[0..BIOS_SIZE];
    }

    override {
        void write_word(Word address, Word value) { write!Word(address, value); }
        void write_half(Word address, Half value) { write!Half(address, value); }
        void write_byte(Word address, Byte value) { write!Byte(address, value); }
        Word read_word(Word address) { return read!Word(address); }
        Half read_half(Word address) { return read!Half(address); }
        Byte read_byte(Word address) { return read!Byte(address); }
    }
}
