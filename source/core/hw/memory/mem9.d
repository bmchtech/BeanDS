module core.hw.memory.mem9;

import core.hw.memory;
import util;

final class Mem9 : Mem {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] main_memory = new Byte[MAIN_MEMORY_SIZE];

    T read(T)(Word address) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x0: .. case 0x1: error_unimplemented("Attempt from ARM9 to read from TCM %x", address); break;
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              error_unimplemented("Attempt from ARM9 to read from WRAM: %x", address); break;
            case 0x4:              error_unimplemented("Attempt from ARM9 to read from ARM9 IO: %x", address); break;
            case 0x5:              error_unimplemented("Attempt from ARM9 to read from PRAM: %x", address); break;
            case 0x6:              error_unimplemented("Attempt from ARM9 to read from VRAM: %x", address); break;
            case 0x7:              error_unimplemented("Attempt from ARM9 to read from OAM: %x", address); break;
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM9 to read from GBA Slot ROM: %x", address); break;
            case 0xA: .. case 0xA: error_unimplemented("Attempt from ARM9 to read from GBA Slot RAM: %x", address); break;
        
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
            case 0x0: .. case 0x1: error_unimplemented("Attempt from ARM9 to write %x to TCM %x", value, address); break;
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value); break;
            case 0x3:              error_unimplemented("Attempt from ARM9 to write %x to WRAM: %x", value, address); break;
            case 0x4:              error_unimplemented("Attempt from ARM9 to write %x to ARM9 IO: %x", value, address); break;
            case 0x5:              error_unimplemented("Attempt from ARM9 to write %x to PRAM: %x", value, address); break;
            case 0x6:              error_unimplemented("Attempt from ARM9 to write %x to VRAM: %x", value, address); break;
            case 0x7:              error_unimplemented("Attempt from ARM9 to write %x to OAM: %x", value, address); break;
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM9 to write %x to GBA Slot ROM: %x", value, address); break;
            case 0xA: .. case 0xA: error_unimplemented("Attempt from ARM9 to write %x to GBA Slot RAM: %x", value, address); break;
        
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