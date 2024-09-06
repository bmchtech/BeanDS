module emu.hw.gpu.vramblock;

import emu.hw.cpu.instructionblock;
import emu.hw.gpu.slottype;
import emu.hw.memory.mem;
import util;

final class VRAMBlock {
    Word address;
    size_t size;
    Byte[] data;
    
    Byte mst;
    Byte offset;
    bool enabled;

    SlotType slot_type;
    bool slot_mapped;
    int  slot; // bitfield
    int  slot_ofs = 0;

    this(size_t size) {
        data = new Byte[size];
        this.size = size;

        this.slot_mapped = false;
    }

    bool in_range(Word access_address) {
        return enabled && address <= access_address && access_address < address + size;
    }

    T read(T)(Word access_address) {
        return data.read!T(access_address - address);
    }

    void write(T)(Word access_address, T value) {
        data.write!T(access_address - address, value);
    }

    InstructionBlock* instruction_read(Word access_address) {
        return data.instruction_read(access_address - address);
    }
}