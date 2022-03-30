module emu.hw.cpu.cp.tcm;

import emu;

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

    void skip_firmware() {
        itcm_virtual_size = 0;
        itcm_region_base  = 0;
        dtcm_region_base  = 0x27C0000;
        dtcm_enabled      = true;
        itcm_enabled      = true;
    }

    static void reset() {
        tcm = new TCM();
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
        return address >= itcm_region_base && address < itcm_region_base + itcm_virtual_size;
    }

    bool in_dtcm(Word address) {
        return address >= dtcm_region_base && address < dtcm_region_base + dtcm_virtual_size;
    }

    import std.stdio : writefln;
    T read_itcm(T)(Word address) {
        writefln("reading from itcm at %x", address);
        return itcm.read!T((address - itcm_region_base) % ITCM_PHYSICAL_SIZE);
    }

    void write_itcm(T)(Word address, T value) {
        writefln("writing %x to itcm at %x",value, address);
        itcm.write!T((address - itcm_region_base) % ITCM_PHYSICAL_SIZE, value);
    }

    T read_dtcm(T)(Word address) {
        writefln("reading from dtcm at %x", address);
        return dtcm.read!T((address - dtcm_region_base) % DTCM_PHYSICAL_SIZE);
    }

    void write_dtcm(T)(Word address, T value) {
        writefln("writing %x to dtcm at %x",value, address);
        dtcm.write!T((address - dtcm_region_base) % DTCM_PHYSICAL_SIZE, value);
    }
}