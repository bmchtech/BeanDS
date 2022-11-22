module emu.hw.cpu.armcpu;

import emu.hw.cpu.architecture;
import emu.hw.cpu.instructionblock;
import std.meta;
import util;

alias pc   = Alias!15;
alias lr   = Alias!14;
alias sp   = Alias!13;

alias Reg = int;

static assert (InstructionBlock.sizeof == INSTRUCTION_BLOCK_SIZE);

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
    Word           get_reg__thumb(int i);
    void           set_reg(int i, Word value);
    void           set_reg(int i, Word value, CpuMode mode);
    void           set_reg__thumb(int i, Word value);

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

    Word           read_word(Word address);
    Half           read_half(Word address);
    Byte           read_byte(Word address);

    void           write_word(Word address, Word value);
    void           write_half(Word address, Half value);
    void           write_byte(Word address, Byte value);

    void           run_idle_cycle();

    bool           in_a_privileged_mode();
    void           update_mode();
    bool           has_spsr();
    
    void           raise_exception(CpuException exception)();
    void           halt();
    void           unhalt();

    static @property Architecture architecture();
}

// CPU modes will be described as the following:
// 1) their encoding in the CPSR register
// 2) their register uniqueness (see the diagram in arm7tdmi.h).
// 3) their offset into the registers array.

enum MODE_USER       = CpuMode(0b10000, 0b01_1111_1111_1111_1111, 18 * 0, "USR");
enum MODE_SYSTEM     = CpuMode(0b11111, 0b01_1111_1111_1111_1111, 18 * 0, "SYS");
enum MODE_SUPERVISOR = CpuMode(0b10011, 0b01_1001_1111_1111_1111, 18 * 1, "SVC");
enum MODE_ABORT      = CpuMode(0b10111, 0b01_1001_1111_1111_1111, 18 * 2, "ABT");
enum MODE_UNDEFINED  = CpuMode(0b11011, 0b01_1001_1111_1111_1111, 18 * 3, "UND");
enum MODE_IRQ        = CpuMode(0b10010, 0b01_1001_1111_1111_1111, 18 * 4, "IRQ");
enum MODE_FIQ        = CpuMode(0b10001, 0b01_1000_0000_1111_1111, 18 * 5, "FIQ");

static immutable CpuMode[7] MODES = [
    MODE_USER, MODE_FIQ, MODE_IRQ, MODE_SUPERVISOR, MODE_ABORT, MODE_UNDEFINED,
    MODE_SYSTEM
];

enum InstructionSet {
    ARM,
    THUMB
}

struct CpuMode {
    this(const(int) c, const(int) r, const(int) o, const(string) s) {
        CPSR_ENCODING = c;
        REGISTER_UNIQUENESS = r;
        OFFSET = o;
        SHORTNAME = s;
    }

    int CPSR_ENCODING;
    int REGISTER_UNIQUENESS;
    int OFFSET;
    string SHORTNAME;
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