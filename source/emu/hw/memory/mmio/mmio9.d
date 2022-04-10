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
    MMIORegister("gpu_engine_a",     "DISPCNT",       0x0400_0000,  4, READ_WRITE),
    MMIORegister("gpu",              "DISPSTAT",      0x0400_0004,  4, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu", "WININ",         0x0400_0048,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu", "WINOUT",        0x0400_004A,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu", "MOSAIC",        0x0400_004C,  2,      WRITE),
    MMIORegister("gpu_engine_a.ppu", "BLDCNT",        0x0400_0050,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu", "BLDALPHA",      0x0400_0052,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu", "BLDY",          0x0400_0054,  2,      WRITE),
    MMIORegister("dma9",             "DMAxSAD",       0x0400_00B0,  4, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",             "DMAxDAD",       0x0400_00B4,  4, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",             "DMAxCNT_L",     0x0400_00B8,  2, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",             "DMAxCNT_H",     0x0400_00BA,  2, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",             "DMAxFILL",      0x0400_00E0,  4, READ_WRITE).repeat(4, 4),
    MMIORegister("timers9",          "TMxCNT_L",      0x0400_0100,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("timers9",          "TMxCNT_H",      0x0400_0102,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("input",            "KEYINPUT",      0x0400_0130,  2, READ),
    MMIORegister("ipc9",             "IPCSYNC",       0x0400_0180,  4, READ_WRITE),
    MMIORegister("ipc9",             "IPCFIFOCNT",    0x0400_0184,  4, READ_WRITE),
    MMIORegister("ipc9",             "IPCFIFOSEND",   0x0400_0188,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("ipc9",             "IPCFIFORECV",   0x0410_0000,  4, READ      ).dont_decompose_into_bytes(),
    MMIORegister("auxspi",           "ROMCTRL",       0x0400_01A4,  4, READ_WRITE),
    MMIORegister("slot",             "EXMEMCNT",      0x0400_0204,  2, READ_WRITE),
    MMIORegister("interrupt9",       "IME",           0x0400_0208,  4, READ_WRITE),
    MMIORegister("interrupt9",       "IE",            0x0400_0210,  4, READ_WRITE),
    MMIORegister("interrupt9",       "IF",            0x0400_0214,  4, READ_WRITE),
    MMIORegister("vram",             "VRAMCNT",       0x0400_0240, 10, READ_WRITE).filter!((int i) => i != 7)(),
    MMIORegister("wram",             "WRAMCNT",       0x0400_0247,  1, READ_WRITE),
    MMIORegister("math_div",         "DIVCNT",        0x0400_0280,  4, READ_WRITE),
    MMIORegister("math_div",         "DIV_NUMER",     0x0400_0290,  8, READ_WRITE),
    MMIORegister("math_div",         "DIV_DENOM",     0x0400_0298,  8, READ_WRITE),
    MMIORegister("math_div",         "DIV_RESULT",    0x0400_02A0,  8, READ),
    MMIORegister("math_div",         "DIVREM_RESULT", 0x0400_02A8,  8, READ),
    MMIORegister("math_sqrt",        "SQRTCNT",       0x0400_02B0,  4, READ_WRITE),
    MMIORegister("math_sqrt",        "SQRT_RESULT",   0x0400_02B4,  4, READ),
    MMIORegister("math_sqrt",        "SQRT_PARAM",    0x0400_02B8,  8, READ_WRITE),
    MMIORegister("nds",              "POSTFLG",       0x0400_0300,  4, READ),
    MMIORegister("n/a",              "POWCNT1",       0x0400_0304,  4, READ_WRITE).unimplemented(),
    MMIORegister("gpu_engine_b",     "DISPCNT",       0x0400_1000,  4, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu", "BGxCNT",        0x0400_1008,  2, READ_WRITE).repeat(4, 2),
    MMIORegister("gpu_engine_b.ppu", "BGxHOFS",       0x0400_1010,  2,      WRITE).repeat(4, 4),
    MMIORegister("gpu_engine_b.ppu", "BGxVOFS",       0x0400_1012,  2,      WRITE).repeat(4, 4),
    MMIORegister("gpu_engine_b.ppu", "WINxH",         0x0400_1040,  2,      WRITE).repeat(2, 2),
    MMIORegister("gpu_engine_b.ppu", "WINxV",         0x0400_1044,  2,      WRITE).repeat(2, 2),
    MMIORegister("gpu_engine_b.ppu", "WININ",         0x0400_1048,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu", "WINOUT",        0x0400_104A,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu", "MOSAIC",        0x0400_104C,  2,      WRITE),
    MMIORegister("gpu_engine_b.ppu", "BLDCNT",        0x0400_1050,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu", "BLDALPHA",      0x0400_1052,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu", "BLDY",          0x0400_1054,  2,      WRITE)
];
