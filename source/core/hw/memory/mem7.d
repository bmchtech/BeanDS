module core.hw.memory.mem7;

import common;
import core.hw.mem;
import util;

struct Mem7 {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] main_memory = new Byte[MAIN_MEMORY_SIZE];

    T read(T)(Word address) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);

        final switch (region) {
            case 0x0: .. case 0x1: error_unimplemented("Attempt from ARM7 to read from BIOS %x", address);
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              error_unimplemented("Attempt from ARM7 to read from WRAM: %x", address);
            case 0x4:              error_unimplemented("Attempt from ARM7 to read from ARM7 IO: %x", address);
            case 0x6:              error_unimplemented("Attempt from ARM7 to read from VRAM: %x", address);
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM7 to read from GBA Slot ROM: %x", address);
            case 0xA: .. case 0xA: error_unimplemented("Attempt from ARM7 to read from GBA Slot RAM: %x", address);
        
            default: error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);
        }

        // should never happen
        assert(0);
    }

    void write(T)(Word address, T value) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to write %x to an invalid region of memory: %x", value, address);

        final switch (region) {
            case 0x0: .. case 0x1: error_unimplemented("Attempt from ARM7 to write %x to BIOS %x", value, address);
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value);
            case 0x3:              error_unimplemented("Attempt from ARM7 to write %x to WRAM: %x", value, address);
            case 0x4:              error_unimplemented("Attempt from ARM7 to write %x to ARM7 IO: %x", value, address);
            case 0x6:              error_unimplemented("Attempt from ARM7 to write %x to VRAM: %x", value, address);
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM7 to write %x to GBA Slot ROM: %x", value, address);
            case 0xA: .. case 0xA: error_unimplemented("Attempt from ARM7 to write %x to GBA Slot RAM: %x", value, address);
        
            default: error_unimplemented("Attempt from ARM7 to write %x to an invalid region of memory: %x", value, address);
        }
    }
}