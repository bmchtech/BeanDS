module emu.hw.memory.wram;

import emu.hw.cpu.armcpu;
import emu.hw.memory.mem;
import emu.hw.memory.strategy.memstrategy;
import util;

__gshared WRAM wram;
final class WRAM {
    MemStrategy mem;

    Byte mode;

    this(MemStrategy mem) {
        this.mem = mem;
    }

    void direct_boot() {
        set_mode(3);
    }

    void set_mode(int new_mode) {
        mode = new_mode;
        mem.wram_set_mode(new_mode);
    }

    Byte read_WRAMCNT(int target_byte) {
        return mode;
    }

    void write_WRAMCNT(int target_byte, Byte value) {
        set_mode(value[0..1]);
    }

    Byte read_WRAMSTAT(int target_byte) {
        return mode;
    }
}