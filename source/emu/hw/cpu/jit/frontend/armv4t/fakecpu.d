module emu.hw.cpu.jit.frontend.armv4t.fakecpu;

import emu;

import util;

final class FakeCPU(HostReg, Architecture architecture) : ArmCPU {
    IR!(HostReg, GuestReg_ARMv4T)* ir;

    this(IR!(HostReg, GuestReg_ARMv4T)* ir) {
        this.ir = ir;
    }

    pragma(inline, true) Word get_reg(Reg id) {
        Word w = create_new_variable!Word();
        ir.emit_get_reg(w, cast(GuestReg_ARMv4T) id);
        return w;
    }

    pragma(inline, true) void set_reg(Reg id, Word value) {
        ir.emit_set_reg(cast(GuestReg_ARMv4T) id, value.variable);
    }

    pragma(inline, true) Word get_reg(Reg id, CpuMode mode) {
        if (mode == MODE_USER) error_jit("cannot set a non-user mode reg from the JIT.");
        ir.emit_get_user_reg(cast(GuestReg_ARMv4T) id);
    }

    pragma(inline, true) void set_reg(Reg id, Word value, CpuMode mode) {
        if (mode == MODE_USER) error_jit("cannot set a non-user mode reg from the JIT.");

        Word w = create_new_variable!Word();
        ir.emit_set_user_reg(cast(GuestReg_ARMv4T) id, value.variable);
        return w;
    }

    Word get_cpsr() {
        return get_reg(GuestReg_ARMv4T.CPSR);
    }

    Word get_spsr() {
        // user and system modes dont have spsr. spsr reads return cpsr.
        // i'll have to think of a way to model that.

        // if a rom really abuses this fact, then i need to have a word with
        // the people who programmed it.

        return get_reg(GuestReg_ARMv4T.SPSR);
    }

    void set_cpsr(Word cpsr) {
        set_reg(GuestReg_ARMv4T.CPSR, cpsr);

        // need to think of a way to update this variable.
        // maybe i dont have to update it at all?
        // instruction_set = get_flag(Flag.T) ? instruction_set.THUMB : instruction_set.ARM;
    }

    void set_spsr(Word spsr) {
        set_reg(GuestReg_ARMv4T.SPSR, spsr);
    }

    InstructionSet get_instruction_set() { 
        error_jit(0, "you should not call this function with the JIT.");
    }

    Word get_pipeline_entry(int i) {
        error_jit(0, "you should not call this function with the JIT.");
    }

    bool check_cond(uint cond) {
        switch (cond) {
            case 0x0: return ( get_flag(Flag.Z));
            case 0x1: return (!get_flag(Flag.Z));
            case 0x2: return ( get_flag(Flag.C));
            case 0x3: return (!get_flag(Flag.C));
            case 0x4: return ( get_flag(Flag.N));
            case 0x5: return (!get_flag(Flag.N));
            case 0x6: return ( get_flag(Flag.V));
            case 0x7: return (!get_flag(Flag.V));
            case 0x8: return ( get_flag(Flag.C) && !get_flag(Flag.Z));
            case 0x9: return (!get_flag(Flag.C) ||  get_flag(Flag.Z));
            case 0xA: return ( get_flag(Flag.N) ==  get_flag(Flag.V));
            case 0xB: return ( get_flag(Flag.N) !=  get_flag(Flag.V));
            case 0xC: return (!get_flag(Flag.Z) && (get_flag(Flag.N) == get_flag(Flag.V)));
            case 0xD: return ( get_flag(Flag.Z) || (get_flag(Flag.N) != get_flag(Flag.V)));
            case 0xE: return true;
            case 0xF: error_arm7("ARM7 opcode has a condition of 0xF"); return false;

            default: assert(0);
        }
    }

    void refill_pipeline() {
        error_jit(0, "you should not call this function with the JIT.");
    }

    void set_flag(Flag flag, bool value) {
        Word cpsr = get_cpsr();
        cpsr[flag] = value;
        set_cpsr(cpsr);

        // again, no idea if i need to update you for the jit
        // if (flag == Flag.T) {
            // instruction_set = value ? InstructionSet.THUMB : InstructionSet.ARM;
        // }
    }

    bool get_flag(Flag flag) {
        return cast(bool) get_cpsr()[flag];
    }

    Word read_word(Word address, AccessType access_type) {
        Word w = create_new_variable!Word;
        ir.emit_read(address, w, 4);
        return w; 
    }

    Half read_half(Word address, AccessType access_type) {
        Half h = create_new_variable!Half;
        ir.emit_read(address, h, 2);
        return h;
    }

    Byte read_byte(Word address, AccessType access_type) {
        Byte b = create_new_variable!Byte;
        ir.emit_read(address, b, 1);
        return b;
    }

    void write_word(Word address, Word value, AccessType access_type) {
        ir.emit_write(address, value, 4);
    }

    void write_half(Word address, Half value, AccessType access_type) {
        ir.emit_write(address, value, 2);
    }

    void write_byte(Word address, Byte value, AccessType access_type) {
        ir.emit_write(address, value, 1);
    }

    void run_idle_cycle() {
        error_jit(0, "you should not call this function with the JIT.");
    }

    void set_pipeline_access_type(AccessType access_type) {
        error_jit(0, "you should not call this function with the JIT.");
    }

    bool in_a_privileged_mode() {
        // not a clue how to emulate you in the jit...
        error_jit(0, "you should not call this function with the JIT.");
    }

    void update_mode() {
        error_jit(0, "you should not call this function with the JIT.");
    }

    bool has_spsr() {
        error_jit(0, "you should not call this function with the JIT.");
        // return !(current_mode == MODE_USER || current_mode == MODE_SYSTEM);
    }

    void raise_exception(CpuException exception)() {
        if (exception != CPUException.SoftwareInterrupt) {
            error_jit("cannot raise a non-SWI exception from the JIT.");
        }

        ir.emit_swi();
    }

    void halt() {
        error_jit(0, "you should not call this function with the JIT.");
    }

    void unhalt() {
        error_jit(0, "you should not call this function with the JIT.");
    }

    @property
    static Architecture architecture() {
        return architecture;
    }
}