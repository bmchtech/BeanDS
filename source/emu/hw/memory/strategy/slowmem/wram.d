module emu.hw.memory.strategy.slowmem.wram;

import emu.hw.cpu.instructionblock;
import emu.hw.memory.strategy.common;
import emu.hw.memory.mem;
import util;

final class SlowMemWRAM {
    Byte[WRAM_SIZE] shared_bank_1;
    Byte[WRAM_SIZE] shared_bank_2;
    Byte[WRAM_SIZE]*[2] arm7_mapping;
    Byte[WRAM_SIZE]*[2] arm9_mapping;
    
    Byte[ARM7_ONLY_WRAM_SIZE] arm7_only_wram;

    bool arm7_wram_enabled;
    bool arm9_wram_enabled;

    this() {
        shared_bank_1  = new Byte[WRAM_SIZE];
        shared_bank_2  = new Byte[WRAM_SIZE];
        arm7_only_wram = new Byte[ARM7_ONLY_WRAM_SIZE];
    }

    void set_mode(int new_mode) {
        final switch (new_mode) {
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

    T read_data7(T)(Word address) {
        T value;
        if (address < 0x0380_0000 && arm7_wram_enabled) {
            value = (*(arm7_mapping[address[14]])).read!T(address % WRAM_SIZE);
        } else {
            value = arm7_only_wram.read!T(address % ARM7_ONLY_WRAM_SIZE);
        }

        return value;
    }

    void write_data7(T)(Word address, T value) {
        if (address < 0x0380_0000 && arm7_wram_enabled) {
            (*(arm7_mapping[address[14]])).write!T(address % WRAM_SIZE, value);
        } else {
            arm7_only_wram.write!T(address % ARM7_ONLY_WRAM_SIZE, value);
        }
    }

    T read_data9(T)(Word address) {
        if (!arm9_wram_enabled) error_wram("ARM9 tried to read from WRAM at %x when it wasn't allowed to.", address);
        return (*(arm9_mapping[address[14]])).read!T(address % WRAM_SIZE);
    }

    void write_data9(T)(Word address, T value) {
        if (!arm9_wram_enabled) error_wram("ARM9 tried to write %x to WRAM at %x when it wasn't allowed to.", value, address);
        (*(arm9_mapping[address[14]])).write!T(address % WRAM_SIZE, value);
    }

    InstructionBlock* instruction_read7(Word address) {
        if (address < 0x0380_0000 && arm7_wram_enabled) {
            return (*(arm7_mapping[address[14]])).instruction_read(address % WRAM_SIZE);
        } else {
            return arm7_only_wram.instruction_read(address % ARM7_ONLY_WRAM_SIZE);
        }
    }

    InstructionBlock* instruction_read9(Word address) {
        if (!arm9_wram_enabled) error_wram("ARM9 tried to perform an instruction read from WRAM at %x when it wasn't allowed to.", address);
        return (*(arm9_mapping[address[14]])).instruction_read(address % WRAM_SIZE);
    }
}