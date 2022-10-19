module emu.hw.cpu.jumptable.ops;

import emu.hw.cpu;
import emu.hw.memory;

import util;

void set_reg_wrapper(T : ArmCPU, bool lower_regs)(T cpu, int reg, Word value) {
    static if (lower_regs) {
        cpu.set_reg__thumb(reg, value);
    } else {
        cpu.set_reg(reg, value);
    }
}

Word get_reg_wrapper(T : ArmCPU, bool lower_regs)(T cpu, int reg) {
    static if (lower_regs) {
        return cpu.get_reg__thumb(reg);
    } else {
        return cpu.get_reg(reg);
    }
}

void add(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 + operand2;

    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);

    if (set_flags) {
        cpu.set_flag(Flag.N, result[31]);
        cpu.set_flag(Flag.Z, result == 0);

        cpu.set_flag(Flag.C, (cast(u64) operand1 + cast(u64) operand2) >= 0x1_0000_0000);
        cpu.set_flag(Flag.V, ((operand1 >> 31) == (operand2 >> 31)) && ((operand1 >> 31) ^ (result >> 31)));
    }
}

void sub(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 - operand2;

    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);

    if (set_flags) {
        cpu.set_flags_NZ(result);

        cpu.set_flag(Flag.C, cast(u64) operand2 <= cast(u64) operand1);
        cpu.set_flag(Flag.V, ((operand2 >> 31) ^ (operand1 >> 31)) && ((operand2 >> 31) == (result >> 31)));
    }
}

void adc(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 + operand2 + cpu.get_flag(Flag.C);

    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);

    if (set_flags) {
        cpu.set_flags_NZ(result);

        cpu.set_flag(Flag.C, (cast(u64) operand1 + cast(u64) operand2 + cpu.get_flag(Flag.C)) >= 0x1_0000_0000);
        cpu.set_flag(Flag.V, ((operand1 >> 31) == (operand2 >> 31)) && ((operand1 >> 31) ^ (result >> 31)));
    }
}

void sbc(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    u64 operand2_carry = cast(u64) operand2 + cast(u64) (cpu.get_flag(Flag.C) ? 0 : 1);
    Word result = operand1 - cast(u32) operand2_carry;

    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);

    if (set_flags) {
        cpu.set_flags_NZ(result);

        cpu.set_flag(Flag.C, operand2_carry <= operand1);
        cpu.set_flag(Flag.V, ((operand2 >> 31) ^ (operand1 >> 31)) && ((operand2 >> 31) == (result >> 31)));
    }
}

void mov(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word immediate, bool set_flags = true) {
    cpu.set_reg_wrapper!(T, lower_regs)(rd, immediate);
    if (set_flags) cpu.set_flags_NZ(immediate);
}

void cmp(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool set_flags = true) {
    sub(cpu, rd, operand1, operand2, false, set_flags);
}

void and(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 & operand2;
    if (set_flags) cpu.set_flags_NZ(result);
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void rsb(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    sub(cpu, rd, operand2, operand1, writeback, set_flags);
}

void rsc(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    sbc(cpu, rd, operand2, operand1, writeback, set_flags);
}

void tst(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool set_flags = true) {
    and(cpu, rd, operand1, operand2, false, set_flags);
}

void teq(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool set_flags = true) {
    eor(cpu, rd, operand1, operand2, false, set_flags);
}

void eor(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 ^ operand2;
    if (set_flags) cpu.set_flags_NZ(result);
    if (rd == pc) log_arm9("shitter: %x %x %x", rd, result, arm9.internal_read!Word(result));
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void lsl(T : ArmCPU, bool lower_regs = false, S)(T cpu, Reg rd, Word operand, S shift, bool writeback = true, bool set_flags = true) {
    Word result;
    bool carry;

    if (shift < 32) {
        result = operand << shift;
        carry  = operand[32 - shift];
    } else if (shift == 32) {
        result = 0;
        carry  = operand[0];
    } else { // shift > 32
        result = 0;
        carry  = false;
    }

    if (set_flags) {
        cpu.set_flags_NZ(result);
        cpu.set_flag(Flag.C, carry);
    }

    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void lsr(T : ArmCPU, bool lower_regs = false, S)(T cpu, Reg rd, Word operand, S shift, bool writeback = true, bool set_flags = true) {
    Word result;
    bool carry;

    if        (shift == 0) {
        result = operand;
        carry = cpu.get_flag(Flag.C);
        writeback = false; // TODO: CHECK THIS!!!!
    } else if (shift < 32) {
        result = operand >> shift;
        carry  = operand[shift - 1];
    } else if (shift == 32) {
        result = 0;
        carry  = operand[31];
    } else { // shift > 32
        result = 0;
        carry  = false;
    }

    if (set_flags) {
        cpu.set_flags_NZ(result);
        cpu.set_flag(Flag.C, carry);
    }
    
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void asr(T : ArmCPU, bool lower_regs = false, S)(T cpu, Reg rd, Word operand, S shift, bool writeback = true, bool set_flags = true) {
    Word result;
    bool carry;

    if        (shift == 0) {
        result = operand;
        carry  = cpu.get_flag(Flag.C);
    } else if (shift < 32) {
        result = sext_32(operand >> shift, 32 - shift);
        carry  = operand[shift - 1];
    } else { // shift >= 32
        result = operand[31] ? ~0 : 0;
        carry  = operand[31];
    }

    if (set_flags) {
        cpu.set_flags_NZ(result);
        cpu.set_flag(Flag.C, carry);
    }
    
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void ror(T : ArmCPU, bool lower_regs = false, S)(T cpu, Reg rd, Word operand, S shift, bool writeback = true, bool set_flags = true) {
    Word result = operand.rotate_right(shift & 0x1F);

    if (shift == 0) {
        cpu.set_flags_NZ(operand);
        return; // CHECK THIS
    }

    if ((shift & 0x1F) == 0) {
        cpu.set_flag(Flag.C, operand[31]);
    } else {
        cpu.set_flag(Flag.C, operand[(shift & 0x1F) - 1]);
    }

    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
    if (set_flags) cpu.set_flags_NZ(result);
}

void tst(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2) {
    cpu.and(rd, operand1, operand2, false);
}

void neg(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word immediate, bool writeback = true, bool set_flags = true) {
    sub(cpu, rd, Word(0), immediate, writeback, set_flags);
}

void cmn(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool set_flags = true) {
    cpu.add(rd, operand1, operand2, false, set_flags);
}

void orr(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 | operand2;
    if (set_flags) cpu.set_flags_NZ(result);
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void mul(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 * operand2;

    int idle_cycles = calculate_multiply_cycles!true(operand1);
    for (int i = 0; i < idle_cycles; i++) cpu.run_idle_cycle();

    if (set_flags) cpu.set_flags_NZ(result);
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void bic(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word operand1, Word operand2, bool writeback = true, bool set_flags = true) {
    Word result = operand1 & ~operand2;
    if (set_flags) cpu.set_flags_NZ(result);
    if (writeback) cpu.set_reg_wrapper!(T, lower_regs)(rd, result);
}

void mvn(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word immediate, bool set_flags = true) {
    cpu.set_reg_wrapper!(T, lower_regs)(rd, ~immediate);
    if (set_flags) cpu.set_flags_NZ(~immediate);
}

void set_flags_NZ(T : ArmCPU, bool lower_regs = false)(T cpu, Word result) {
    cpu.set_flag(Flag.Z, result == 0);
    cpu.set_flag(Flag.N, result[31]);
}

void ldr(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    Word value = cpu.read_word_and_rotate(address);
    if (v5TE!T && rd == pc) cpu.set_flag(Flag.T, value[0]);

    cpu.set_reg_wrapper!(T, lower_regs)(rd, value);
    cpu.run_idle_cycle();
}

void ldrh(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    cpu.set_reg_wrapper!(T, lower_regs)(rd, cpu.read_half_and_rotate(address));
    cpu.run_idle_cycle();
}

void ldrb(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    cpu.set_reg_wrapper!(T, lower_regs)(rd, cast(Word) cpu.read_byte(address));
    cpu.run_idle_cycle();
}

void ldrsb(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    cpu.set_reg_wrapper!(T, lower_regs)(rd, cast(Word) sext_32(cpu.read_byte(address), 8));
    cpu.run_idle_cycle();
}

void ldrd(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    if (rd & 1) error_arm9("LDRD with an odd numbered RD was attempted.");

    cpu.ldr(rd,     address);
    cpu.ldr(rd + 1, address + 4);
}

void ldrsh(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    if (address & 1) {
        static if (v5TE!T) {
            ldrsh(cpu, rd, address & ~1);
        } else {
            ldrsb(cpu, rd, address);
        }
    } else {
        cpu.set_reg_wrapper!(T, lower_regs)(rd, cast(Word) sext_32(cpu.read_half(address), 16));
        cpu.run_idle_cycle();
    }
}

void str(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    Word value = cpu.get_reg_wrapper!(T, lower_regs)(rd);
    if (unlikely(rd == pc)) value += 4;

    cpu.write_word(address & ~3, value);
}

void strh(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    Word value = cpu.get_reg_wrapper!(T, lower_regs)(rd);
    if (unlikely(rd == pc)) value += 4;

    cpu.write_half(address & ~1, cast(Half) (value & 0xFFFF));
}

void strb(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    Word value = cpu.get_reg_wrapper!(T, lower_regs)(rd);
    if (unlikely(rd == pc)) value += 4;

    cpu.write_byte(address, cast(Byte) (value & 0xFF));
}

void strd(T : ArmCPU, bool lower_regs = false)(T cpu, Reg rd, Word address) {
    if (rd & 1) error_arm9("STRD with an odd numbered RD was attempted.");

    cpu.str(rd,     address);
    cpu.str(rd + 1, address + 4);
}


void swi(T : ArmCPU, bool lower_regs = false)(T cpu) {
    cpu.raise_exception!(CpuException.SoftwareInterrupt);
}

Word read_word_and_rotate(ArmCPU cpu, Word address) {
    Word value = cpu.read_word(address & ~3);
    auto misalignment = address & 0b11;
    return value.rotate_right(misalignment * 8);
}

Word read_half_and_rotate(ArmCPU cpu, Word address) {
    Word value = cast(Word) cpu.read_half(address & ~1);
    auto misalignment = address & 0b1;
    return value.rotate_right(misalignment * 8);
}

static int calculate_multiply_cycles(bool signed)(Word operand) {
    int m = 4;

    static if (signed) {
        if      ((operand >>  8) == 0xFFFFFF) m = 1;
        else if ((operand >> 16) == 0xFFFF)   m = 2;
        else if ((operand >> 24) == 0xFF)     m = 3;
    }

    if      ((operand >> 8)  == 0x0) m = 1;
    else if ((operand >> 16) == 0x0) m = 2;
    else if ((operand >> 24) == 0x0) m = 3;
    return m;
}