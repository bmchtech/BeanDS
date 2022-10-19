module emu.hw.memory.main_memory;

import emu;
import util;

__gshared MainMemory main_memory;

final class MainMemory {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] data;

    T read(T)(Word address) {
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205650c & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205650e & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056510 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205fa8 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("reading A button: %x", arm9.regs[pc]);
        }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056514 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056516 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056518 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205651a & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205651c & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205651e & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056520 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056522 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056524 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        // if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02056526 & (MAIN_MEMORY_SIZE - 1)))) {
        //     return T(1);
        // }
        return data.read!T(address & (MAIN_MEMORY_SIZE - 1));
    }

    void write(T)(Word address, T value) {
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x27fffa8 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afa8 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x at PCs %x %x", value, address, arm9.regs[pc], arm7.regs[pc]);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afaa & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afac & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afae & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afb0 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afb2 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afb4 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afb6 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afb8 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afba & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afbc & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afbe & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afc0 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x0205afc2 & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("writing %x to the stupid fucking address %x", value, address);
        }
        if (((address & (MAIN_MEMORY_SIZE - 1)) == (0x02054bfc & (MAIN_MEMORY_SIZE - 1)))) {
            log_arm9("stupid fucking fucker %x %x", value, address);
        }
        

        data.write!T(address & (MAIN_MEMORY_SIZE - 1), value);
    }

    InstructionBlock* instruction_read(Word address) {
        return data.instruction_read(address & (MAIN_MEMORY_SIZE - 1));
    }
}