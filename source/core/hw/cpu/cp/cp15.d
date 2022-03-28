module core.hw.cpu.cp.cp15;

import util;

__gshared Cp15 cp15;
final class Cp15 {
    static void reset() {
        cp15 = new Cp15();
    }

    Word read(Word opcode, Word cn, Word cm) {
        log_coprocessor("Received a CP15 read: %x %x %x", opcode, cn, cm);
        return Word(0);
    }
}