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
    MMIORegister("ipc7",         "IPCSYNC",       0x0400_0180,  2, READ_WRITE),
    MMIORegister("ipc7",         "IPCFIFOCNT",    0x0400_0184,  2, READ_WRITE),
    MMIORegister("ipc7",         "IPCFIFOSEND",   0x0400_0188,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("ipc7",         "IPCFIFORECV",   0x0410_0000,  4, READ      ).dont_decompose_into_bytes(),
    MMIORegister("interrupt7",   "IME",           0x0400_0208,  4, READ_WRITE),
    MMIORegister("interrupt7",   "IE",            0x0400_0210,  4, READ_WRITE),
    MMIORegister("interrupt7",   "IF",            0x0400_0214,  4, READ_WRITE),
];