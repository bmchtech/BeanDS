module core.hw.memory.mem9;

import core.hw;
import util;

final class Mem9 : Mem {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] main_memory = new Byte[MAIN_MEMORY_SIZE];

    // very crappy implementation of tcm but i just want to get armwrestler booting
    enum TCM_SIZE = 1 << 15;
    Byte[TCM_SIZE] tcm = new Byte[TCM_SIZE];

    MMIO9 mmio9;

    this() {
        new MMIO9();
        new DMA9(this);
    }

    T read(T)(Word address) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x0: .. case 0x1: return tcm.read!T(address % TCM_SIZE);
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              return shared_wram.read!T(address % SHARED_WRAM_SIZE);
            case 0x4:              return mmio9.read!T(address);
            case 0x5:              return pram.read!T(address);
            case 0x6:              return vram.read!T(address);
            case 0x7:              error_unimplemented("Attempt from ARM9 to read from OAM: %x", address); break;
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM9 to read from GBA Slot ROM: %x", address); break;
            case 0xA: .. case 0xB: error_unimplemented("Attempt from ARM9 to read from GBA Slot RAM: %x", address); break;
        
            default: error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address); break;
        }

        // should never happen
        assert(0);
    }

    void write(T)(Word address, T value) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address);

        switch (region) {
            case 0x0: .. case 0x1: tcm.write!T(address % TCM_SIZE, value); break;
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value); break;
            case 0x3:              shared_wram.write!T(address % SHARED_WRAM_SIZE, value); break;
            case 0x4:              mmio9.write!T(address, value); break;
            case 0x5:              pram.write!T(address, value); break;
            case 0x6:              vram.write!T(address, value); break;
            case 0x7:              error_unimplemented("Attempt from ARM9 to write %x to OAM: %x", value, address); break;
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM9 to write %x to GBA Slot ROM: %x", value, address); break;
            case 0xA: .. case 0xB: error_unimplemented("Attempt from ARM9 to write %x to GBA Slot RAM: %x", value, address); break;
        
            default: error_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address); break;
        }
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
