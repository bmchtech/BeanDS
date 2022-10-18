module emu.hw.cpu.jit.frontend.armv4t.guest_reg;

import std.conv;
import std.uni;

enum GuestReg {
    R0,
    R1,
    R2,
    R3,
    R4,
    R5,
    R6,
    R7,
    R8,
    R9,
    R10,
    R11,
    R12,
    SP,
    LR,
    PC,
    CPSR,
    SPSR
}

string to_string(GuestReg reg) {
    return std.conv.to!string(reg).toLower();
}