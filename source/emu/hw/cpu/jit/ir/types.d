module emu.hw.cpu.jit.ir.types;

enum IRBinaryDataOp {
    AND,
    LSL,
    OR
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
    T = 5,
}