module emu.hw.memory.mem9;

import emu;

import util;

__gshared Mem9 mem9;
final class Mem9 : Mem {
    enum BIOS_SIZE = 3072;
    Byte[BIOS_SIZE] bios = new Byte[BIOS_SIZE];

    private this() {
        MMIO9.reset();
        TCM.reset();
    }

    static void reset() {
        mem9 = new Mem9();
    }

    void skip_firmware() {
        tcm.skip_firmware();
    }

    T read(T)(Word address) {
        check_memory_unit!T;

        if (tcm.can_read_itcm(address)) return tcm.read_itcm!T(address);
        if (tcm.can_read_dtcm(address)) return tcm.read_dtcm!T(address);

        auto region = get_region(address);

        if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              return wram.read9!T(address);
            case 0x4:              return mmio9.read!T(address);
            case 0x5:              return pram.read!T(address);
            case 0x6:              return vram.read9!T(address);
            case 0x7:              return oam.read!T(address);
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM9 to read from GBA Slot ROM: %x", address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM9 to read from GBA Slot RAM: %x", address); break;
            case 0xF:              return bios.read!T(address[0..15]);
        
            default: error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address); break;
        }

        // should never happen
        // assert(0);
        return T(0);
    }

    void write(T)(Word address, T value) {
        check_memory_unit!T;

        if (tcm.can_write_itcm(address)) { tcm.write_itcm!T(address, value); return; }
        if (tcm.can_write_dtcm(address)) { tcm.write_dtcm!T(address, value); return; }

        auto region = get_region(address);

        if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address);

        switch (region) {
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value); break;
            case 0x3:              wram.write9!T(address, value); break;
            case 0x4:              mmio9.write!T(address, value); break;
            case 0x5:              pram.write!T(address, value); break;
            case 0x6:              vram.write9!T(address, value); break;
            case 0x7:              oam.write!T(address, value); break;
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM9 to write %x to GBA Slot ROM: %x", value, address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM9 to write %x to GBA Slot RAM: %x", value, address); break;
            case 0xF:              error_mem9("Attempt to write %x to BIOS: %x", value, address); break;
        
            default: error_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address); break;
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
