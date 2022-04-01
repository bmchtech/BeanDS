module emu.hw.memory.mmio.mmio9;

import emu.hw;

import util;

__gshared MMIO!mmio9_registers mmio9;
final class MMIO9 {
    static void reset() {
        mmio9 = new MMIO!mmio9_registers("MMIO9");
    }
}

static const mmio9_registers = [
    MMIORegister("gpu_engine_a", "DISPCNT",       0x0400_0000,  4, READ_WRITE),
    MMIORegister("gpu",          "DISPSTAT",      0x0400_0004,  4, READ_WRITE),
    MMIORegister("dma9",         "DMAxSAD",       0x0400_00B0,  4, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",         "DMAxDAD",       0x0400_00B4,  4, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",         "DMAxCNT_L",     0x0400_00B8,  2, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",         "DMAxCNT_H",     0x0400_00BA,  2, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",         "DMAxFILL",      0x0400_00E0,  4, READ_WRITE).repeat(4, 4),
    MMIORegister("timers9",      "TMxCNT_L",      0x0400_0100,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("timers9",      "TMxCNT_H",      0x0400_0102,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("input",        "KEYINPUT",      0x0400_0130,  2, READ),
    MMIORegister("ipc9",         "IPCSYNC",       0x0400_0180,  2, READ_WRITE),
    MMIORegister("ipc9",         "IPCFIFOCNT",    0x0400_0184,  2, READ_WRITE),
    MMIORegister("ipc9",         "IPCFIFOSEND",   0x0400_0188,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("ipc9",         "IPCFIFORECV",   0x0410_0000,  4, READ      ).dont_decompose_into_bytes(),
    MMIORegister("interrupt9",   "IME",           0x0400_0208,  4, READ_WRITE),
    MMIORegister("interrupt9",   "IE",            0x0400_0210,  4, READ_WRITE),
    MMIORegister("interrupt9",   "IF",            0x0400_0214,  4, READ_WRITE),
    MMIORegister("vram",         "VRAMCNT",       0x0400_0240, 10,      WRITE).filter!((int i) => i != 7)(),
    MMIORegister("wram",         "WRAMCNT",       0x0400_0247,  1, READ_WRITE),
    MMIORegister("math_div",     "DIVCNT",        0x0400_0280,  4, READ_WRITE),
    MMIORegister("math_div",     "DIV_NUMER",     0x0400_0290,  8, READ_WRITE),
    MMIORegister("math_div",     "DIV_DENOM",     0x0400_0298,  8, READ_WRITE),
    MMIORegister("math_div",     "DIV_RESULT",    0x0400_02A0,  8, READ),
    MMIORegister("math_div",     "DIVREM_RESULT", 0x0400_02A8,  8, READ),
    MMIORegister("math_sqrt",    "SQRTCNT",       0x0400_02B0,  4, READ_WRITE),
    MMIORegister("math_sqrt",    "SQRT_RESULT",   0x0400_02B4,  4, READ),
    MMIORegister("math_sqrt",    "SQRT_PARAM",    0x0400_02B8,  8, READ_WRITE),
];