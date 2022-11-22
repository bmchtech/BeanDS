module emu.hw.memory.mem;

import emu.hw.cpu.instructionblock;

// import emu.hw.cpu.armcpu;
import util;

// enum AccessType {
//     NONSEQUENTIAL,
//     SEQUENTIAL
// }

// abstract class Mem {
//     void memcpy(Word address, Byte* source, size_t size) {
//         for (int i = 0; i < size; i++) {
//             this.write_byte(address + i, source[i]);
//         }
//     }

//     abstract void write_word(Word address, Word value);
//     abstract void write_half(Word address, Half value);
//     abstract void write_byte(Word address, Byte value);
//     abstract Word read_word(Word address);
//     abstract Half read_half(Word address);
//     abstract Byte read_byte(Word address);
// }

auto get_region(Word address) {
    return address[24..27];
}

pragma(inline, true) {
    T read(T)(Byte[] memory, Word address) {
        return (cast(T*) memory)[address >> get_shift!T];
    }

    void write(T)(Byte[] memory, Word address, T value) {
        (cast(T*) memory)[address >> get_shift!T] = value;
    }

    T read(T)(Byte* memory, Word address) {
        return (cast(T*) memory)[address >> get_shift!T];
    }

    void write(T)(Byte* memory, Word address, T value) {
        (cast(T*) memory)[address >> get_shift!T] = value;
    }

    T read(T)(Byte[] memory, int address) {
        return (cast(T*) memory)[address >> get_shift!T];
    }

    void write(T)(Byte[] memory, int address, T value) {
        (cast(T*) memory)[address >> get_shift!T] = value;
    }

    T read(T)(Byte* memory, int address) {
        return (cast(T*) memory)[address >> get_shift!T];
    }

    void write(T)(Byte* memory, int address, T value) {
        (cast(T*) memory)[address >> get_shift!T] = value;
    }
    
    InstructionBlock* instruction_read(Byte* memory, Word address) {
        return &(cast(InstructionBlock*) memory)[address >> get_shift!InstructionBlock];
    }

    InstructionBlock* instruction_read(Byte[] memory, Word address) {
        return &(cast(InstructionBlock*) memory)[address >> get_shift!InstructionBlock];
    }

    auto get_shift(T)() {
        import core.bitop;
        
        static if (is(T == InstructionBlock)) return bsf(INSTRUCTION_BLOCK_SIZE);

        static if (is(T == Word)) return 2;
        static if (is(T == Half)) return 1;
        static if (is(T == Byte)) return 0;
    }
}