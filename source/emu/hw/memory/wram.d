module emu.hw.memory.wram;

import emu;
import util;

__gshared WRAM wram;
final class WRAM {
    enum WRAM_SIZE = 1 << 14;
    Byte[WRAM_SIZE] shared_bank_1;
    Byte[WRAM_SIZE] shared_bank_2;
    Byte[WRAM_SIZE]*[2] arm7_mapping;
    Byte[WRAM_SIZE]*[2] arm9_mapping;

    enum ARM7_ONLY_WRAM_SIZE  = 1 << 16;
    Byte[ARM7_ONLY_WRAM_SIZE] arm7_only_wram;

    bool arm7_wram_enabled;
    bool arm9_wram_enabled;
    Byte mode;

    private this() {
        shared_bank_1  = new Byte[WRAM_SIZE];
        shared_bank_2  = new Byte[WRAM_SIZE];
        arm7_only_wram = new Byte[ARM7_ONLY_WRAM_SIZE];
        set_mode(0);
    }

    static void reset() {
        wram = new WRAM();
    }

    void set_mode(int new_mode) {
        mode = new_mode;

        final switch (mode) {
            case 0:
                arm7_mapping      = [null,           null];
                arm9_mapping      = [&shared_bank_1, &shared_bank_2];
                arm7_wram_enabled = false;
                arm9_wram_enabled = true;
                break;
            case 1:
                arm7_mapping      = [&shared_bank_1, &shared_bank_1];
                arm9_mapping      = [&shared_bank_2, &shared_bank_2];
                arm7_wram_enabled = true;
                arm9_wram_enabled = true;
                break;
            case 2:
                arm7_mapping      = [&shared_bank_2, &shared_bank_2];
                arm9_mapping      = [&shared_bank_1, &shared_bank_1];
                arm7_wram_enabled = true;
                arm9_wram_enabled = true;
                break;
            case 3:
                arm7_mapping      = [&shared_bank_1, &shared_bank_2];
                arm9_mapping      = [null,           null];
                arm7_wram_enabled = true;
                arm9_wram_enabled = false;
                break;
        }
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

    T read7(T)(Word address) {
        if (address < 0x0380_0000 && arm7_wram_enabled) {
            return (*(arm7_mapping[address[14]])).read!T(address % WRAM_SIZE);
        } else {
            return arm7_only_wram.read!T(address % ARM7_ONLY_WRAM_SIZE);
        }
    }

    void write7(T)(Word address, T value) {
        if (address < 0x0380_0000 && arm7_wram_enabled) {
            (*(arm7_mapping[address[14]])).write!T(address % WRAM_SIZE, value);
        } else {
            arm7_only_wram.write!T(address % ARM7_ONLY_WRAM_SIZE, value);
        }
    }

    T read9(T)(Word address) {
        if (!arm9_wram_enabled) error_wram("ARM9 tried to read from WRAM at %x when it wasn't allowed to.", address);
        return (*(arm9_mapping[address[14]])).read!T(address % WRAM_SIZE);
    }

    void write9(T)(Word address, T value) {
        if (!arm9_wram_enabled) error_wram("ARM9 tried to write %x to WRAM at %x when it wasn't allowed to.", value, address);
        (*(arm9_mapping[address[14]])).write!T(address % WRAM_SIZE, value);
    }
}