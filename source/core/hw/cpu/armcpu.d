module emu.hw.cpu.armcpu;

import std.meta;

import emu;

import util;

alias pc   = Alias!15;
alias lr   = Alias!14;
alias sp   = Alias!13;

alias Reg = int;

enum Flag {
    N = 31,
    Z = 30,
    C = 29,
    V = 28,
    Q = 27,
    T = 5
}

interface ArmCPU {
    Word           get_reg(int i);
    Word           get_reg(int i, CpuMode mode);
    void           set_reg(int i, Word value);
    void           set_reg(int i, Word value, CpuMode mode);

    Word           get_cpsr();
    Word           get_spsr();
    void           set_cpsr(Word value);
    void           set_spsr(Word value);

    InstructionSet get_instruction_set();
    Word           get_pipeline_entry(int i);
    bool           check_cond(uint cond);
    void           refill_pipeline();
    void           set_flag(Flag flag, bool value);
    bool           get_flag(Flag flag);

    Word           read_word(Word address, AccessType access_type);
    Half           read_half(Word address, AccessType access_type);
    Byte           read_byte(Word address, AccessType access_type);

    void           write_word(Word address, Word value, AccessType access_type);
    void           write_half(Word address, Half value, AccessType access_type);
    void           write_byte(Word address, Byte value, AccessType access_type);

    void           run_idle_cycle();
    void           set_pipeline_access_type(AccessType access_type);

    bool           in_a_privileged_mode();
    void           update_mode();
    bool           has_spsr();
    
    void           raise_exception(CpuException exception)();

    static @property Architecture architecture();
}

// CPU modes will be described as the following:
// 1) their encoding in the CPSR register
// 2) their register uniqueness (see the diagram in arm7tdmi.h).
// 3) their offset into the registers array.

enum MODE_USER       = CpuMode(0b10000, 0b011111111111111111, 18 * 0);
enum MODE_SYSTEM     = CpuMode(0b11111, 0b011111111111111111, 18 * 0);
enum MODE_SUPERVISOR = CpuMode(0b10011, 0b011001111111111111, 18 * 1);
enum MODE_ABORT      = CpuMode(0b10111, 0b011001111111111111, 18 * 2);
enum MODE_UNDEFINED  = CpuMode(0b11011, 0b011001111111111111, 18 * 3);
enum MODE_IRQ        = CpuMode(0b10010, 0b011001111111111111, 18 * 4);
enum MODE_FIQ        = CpuMode(0b10001, 0b011000000011111111, 18 * 5);

static immutable CpuMode[7] MODES = [
    MODE_USER, MODE_FIQ, MODE_IRQ, MODE_SUPERVISOR, MODE_ABORT, MODE_UNDEFINED,
    MODE_SYSTEM
];

enum InstructionSet {
    ARM,
    THUMB
}

struct CpuMode {
    this(const(int) c, const(int) r, const(int) o) {
        CPSR_ENCODING = c;
        REGISTER_UNIQUENESS = r;
        OFFSET = o;
    }

    int CPSR_ENCODING;
    int REGISTER_UNIQUENESS;
    int OFFSET;
}

enum CpuException {
    Reset,
    Undefined,
    SoftwareInterrupt,
    PrefetchAbort,
    DataAbort,
    IRQ,
    FIQ
}