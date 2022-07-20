module emu.hw.cpu.jit.ir.types;

enum IROperandType {
    VARIABLE,
    CONSTANT
}

enum IRGuestReg {
    R0  = 0,
    R1  = 1,
    R2  = 2,
    R3  = 3,
    R4  = 4,
    R5  = 5,
    R6  = 6,
    R7  = 7,
    R8  = 8,
    R9  = 9,
    R10 = 10,
    R11 = 11,
    R12 = 12,
    SP  = 13,
    LR  = 14,
    PC  = 15
}

enum IRBinaryDataOp {
    AND,
    TST
}

enum IRCond {
    EQ = 0,
    NE = 1,
    CS = 2,
    CC = 3,
    MI = 4,
    PL = 5,
    VS = 6,
    VC = 7,
    HI = 8,
    LS = 9,
    GE = 10,
    LT = 11,
    GT = 12,
    LE = 13,
    AL = 14,

    INVALID = 15
}

enum IRFlag {
    N = 31,
    Z = 30,
    C = 29,
    V = 28,
    Q = 27,
    T = 4,
}