module emu.hw.memory.mmio.mmio7;

import emu.hw;

import util;

__gshared MMIO!mmio7_registers mmio7;
final class MMIO7 {
    static void reset() {
        mmio7 = new MMIO!mmio7_registers("MMIO7");
    }
}

static const mmio7_registers = [
    MMIORegister("gpu",          "DISPSTAT",      0x0400_0004,  4, READ_WRITE),
    MMIORegister("timers7",      "TMxCNT_L",      0x0400_0100,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("timers7",      "TMxCNT_H",      0x0400_0102,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("input",        "KEYINPUT",      0x0400_0130,  2, READ),
    MMIORegister("ipc7",         "IPCSYNC",       0x0400_0180,  2, READ_WRITE),
    MMIORegister("ipc7",         "IPCFIFOCNT",    0x0400_0184,  2, READ_WRITE),
    MMIORegister("ipc7",         "IPCFIFOSEND",   0x0400_0188,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("ipc7",         "IPCFIFORECV",   0x0410_0000,  4, READ      ).dont_decompose_into_bytes(),
    MMIORegister("interrupt7",   "IME",           0x0400_0208,  4, READ_WRITE),
    MMIORegister("interrupt7",   "IE",            0x0400_0210,  4, READ_WRITE),
    MMIORegister("interrupt7",   "IF",            0x0400_0214,  4, READ_WRITE),
    MMIORegister("vram",         "VRAMSTAT",      0x0400_0240,  1, READ),
    MMIORegister("wram",         "WRAMSTAT",      0x0400_0241,  1, READ),
    MMIORegister("nds",          "HALTCNT",       0x0400_0301,  1, READ_WRITE),
    MMIORegister("spu",          "SOUNDxCNT",     0x0400_0400,  4, READ_WRITE).repeat(16, 16),
    MMIORegister("spu",          "SOUNDxSAD",     0x0400_0404,  4,      WRITE).repeat(16, 16),
    MMIORegister("spu",          "SOUNDxTMR",     0x0400_0408,  2,      WRITE).repeat(16, 16),
    MMIORegister("spu",          "SOUNDxPNT",     0x0400_040A,  2,      WRITE).repeat(16, 16),
    MMIORegister("spu",          "SOUNDxLEN",     0x0400_040C,  2,      WRITE).repeat(16, 16),
    MMIORegister("spu",          "SOUNDCNT",      0x0400_0500,  2, READ_WRITE),
    MMIORegister("spu",          "SOUNDBIAS",     0x0400_0504,  2, READ_WRITE),
];