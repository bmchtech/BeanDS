module emu.hw.cpu.cp.tcm;

import emu.hw.cpu.armcpu;
import emu.hw.memory.mem;
import util;

__gshared TCM tcm;
final class TCM {
    enum ITCM_PHYSICAL_SIZE = 1 << 15;
    enum DTCM_PHYSICAL_SIZE = 1 << 14;

    Byte[ITCM_PHYSICAL_SIZE] itcm;
    Byte[DTCM_PHYSICAL_SIZE] dtcm;

    Word itcm_virtual_size;
    Word itcm_region_base;
    bool itcm_enabled;
    bool itcm_load_mode;

    Word dtcm_virtual_size;
    Word dtcm_region_base;
    bool dtcm_enabled;
    bool dtcm_load_mode;

    void direct_boot() {
        itcm_virtual_size = 1 << 25;
        itcm_region_base  = 0;
        dtcm_region_base  = 0x27C0000;
        dtcm_enabled      = true;
        itcm_enabled      = true;
    }
    
    bool can_read_itcm(Word address) {
        return itcm_enabled && in_itcm(address) && !itcm_load_mode;
    }

    bool can_write_itcm(Word address) {
        return itcm_enabled && in_itcm(address);
    }

    bool can_read_dtcm(Word address) {
        return dtcm_enabled && in_dtcm(address) && !dtcm_load_mode;
    }

    bool can_write_dtcm(Word address) {
        return dtcm_enabled && in_dtcm(address);
    }

    bool in_itcm(Word address) {
        return address < itcm_virtual_size;
    }

    bool in_dtcm(Word address) {
        // say the address is 32 bits
        // the upper 20 bits encode the region base. if these upper 20 bits are equal to the region base, 
        // then the address is in dtcm. the bottom 12 bits are a bit trickier. they encode the offset into
        // the region. the region size is always a power of two, therefore we can check that every bit that
        // is set outside the region size is zero.

        return address >= dtcm_region_base && address < dtcm_region_base + dtcm_virtual_size;
    }

    InstructionBlock* read_itcm_instruction(Word address) {
        return cast(InstructionBlock*) &itcm[address & (ITCM_PHYSICAL_SIZE - 1)];
    }

    T read_itcm(T)(Word address) {
        return itcm.read!T(address & (ITCM_PHYSICAL_SIZE - 1));
    }

    void write_itcm(T)(Word address, T value) {
        itcm.write!T(address & (ITCM_PHYSICAL_SIZE - 1), value);
    }

    T read_dtcm(T)(Word address) {
        return dtcm.read!T((address - dtcm_region_base) % DTCM_PHYSICAL_SIZE);
    }

    void write_dtcm(T)(Word address, T value) {
        dtcm.write!T((address - dtcm_region_base) % DTCM_PHYSICAL_SIZE, value);
    }
}