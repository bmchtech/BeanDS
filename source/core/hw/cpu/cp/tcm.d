module core.hw.cpu.cp.tcm;

import core;

import util;

__gshared TCM tcm;
final class TCM {
    enum ITCM_PHYSICAL_SIZE = 1 << 15;
    enum DTCM_PHYSICAL_SIZE = 1 << 14;

    Byte[ITCM_PHYSICAL_SIZE] itcm;
    Byte[DTCM_PHYSICAL_SIZE] dtcm;

    Word itcm_virtual_size;
    Word itcm_region_base;

    Word dtcm_virtual_size;
    Word dtcm_region_base;

    void skip_firmware() {
        itcm_virtual_size = 1 << 25;
        itcm_region_base  = 0;
        dtcm_region_base  = 0x27C0000;
    }

    static void reset() {
        tcm = new TCM();
    }

    bool in_itcm(Word address) {
        return address > itcm_region_base && address < itcm_region_base + itcm_virtual_size;
    }

    bool in_dtcm(Word address) {
        return address > dtcm_region_base && address < dtcm_region_base + dtcm_virtual_size;
    }

    T read_itcm(T)(Word address) {
        return itcm.read!T((address - itcm_region_base) % ITCM_PHYSICAL_SIZE);
    }

    void write_itcm(T)(Word address, T value) {
        itcm.write!T((address - itcm_region_base) % ITCM_PHYSICAL_SIZE, value);
    }

    T read_dtcm(T)(Word address) {
        return dtcm.read!T((address - dtcm_region_base) % DTCM_PHYSICAL_SIZE);
    }

    void write_dtcm(T)(Word address, T value) {
        dtcm.write!T((address - dtcm_region_base) % DTCM_PHYSICAL_SIZE, value);
    }
}