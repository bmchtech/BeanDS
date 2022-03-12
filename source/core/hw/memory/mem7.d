module core.hw.memory.mem7;

import common;
import util;

struct Mem7 {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] main_memory = new Byte[MAIN_MEMORY_SIZE];

    T read(T)(Word address) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);

        final switch (region) {
            case 0x0: .. case 0x1: error_unimplemented("Attempt from ARM7 to access TCM %x", address);
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              error_unimplemented("Attempt from ARM7 to access WRAM: %x", address);
            case 0x4:              error_unimplemented("Attempt from ARM7 to access ARM7 IO: %x", address);
            case 0x6:              error_unimplemented("Attempt from ARM7 to access VRAM: %x", address);
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM7 to access GBA Slot ROM: %x", address);
            case 0xA: .. case 0xA: error_unimplemented("Attempt from ARM7 to access GBA Slot RAM: %x", address);
        
            default: error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);
        }

        // should never happen
        assert(0);
    }

    void write(T)(Word address) {
        check_memory_unit!T;

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);

        final switch (region) {
            case 0x0: .. case 0x1: error_unimplemented("Attempt from ARM7 to access TCM %x", address);
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value);
            case 0x3:              error_unimplemented("Attempt from ARM7 to access WRAM: %x", address);
            case 0x4:              error_unimplemented("Attempt from ARM7 to access ARM7 IO: %x", address);
            case 0x6:              error_unimplemented("Attempt from ARM7 to access VRAM: %x", address);
            case 0x8: .. case 0x9: error_unimplemented("Attempt from ARM7 to access GBA Slot ROM: %x", address);
            case 0xA: .. case 0xA: error_unimplemented("Attempt from ARM7 to access GBA Slot RAM: %x", address);
        
            default: error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);
        }
    }

    auto get_region(Word address) {
        return address[24..27];
    }

    pragma(inline, true)
    T read(T)(Byte[] memory, Word address) {
        return *(cast(T*) memory[address >> T.sizeof]);
    }

    pragma(inline, true)
    void write(T)(Byte[] memory, Word address, T value) {
        *(cast(T*) memory[address >> T.sizeof]) = value;
    }
}