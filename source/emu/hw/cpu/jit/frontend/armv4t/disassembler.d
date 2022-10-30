module emu.hw.cpu.jit.frontend.armv4t.disassembler;

import emu.hw.cpu.jit;
import std.sumtype;
import util;

alias DecodeJumptableEntry = void function(IR* ir, Word opcode);
alias DecodeJumptable = DecodeJumptableEntry[256];

bool matches(string format, uint opcode) {
    bool matches = true;

    for (int i = 0; i < format.length; i++) {
        char f = format[i];
        bool b = opcode.bit(format.length - i - 1);

        if ((f != 'x') && ((f == '1' && b != 1) || (f == '0' && b != 0))) {
            matches = false;
        }
    }

    return matches;
}

// void set_flag(IRFlag ir_flag)(_IR* ir) {
    // int offset = ir_flag;
// }

DecodeJumptable create_decode_jumptable()() {
    DecodeJumptable decode_jumptable;

    static foreach (enum i; 0 .. 256) {
        if ("11010000".matches(i)) {
            // decode_jumptable[i] = &emit_branch_exchange__THUMB!();
        } else

        if ("01000111".matches(i)) {
            decode_jumptable[i] = &emit_branch_exchange__THUMB!();
        } else 

        if ("01000000".matches(i)) {
            decode_jumptable[i] = &emit_create_full_alu__THUMB!();
        }
    }

    return decode_jumptable;
}

enum decode_jumptable = create_decode_jumptable!();

void do_action(IR* ir, Word opcode) {
    decode_jumptable[opcode >> 8](ir, opcode);
}

static void emit_branch_exchange__THUMB()(IR* ir, Word opcode) {
    GuestReg rm = cast(GuestReg) opcode[3..6];

    IRVariable address    = ir.get_reg(rm);
    IRVariable cpsr       = ir.get_reg(GuestReg.CPSR);
    IRVariable thumb_mode = address & 1;

    if (rm == GuestReg.PC) address = address - 2;
    
    cpsr = cpsr & ~(1          << 5);
    cpsr = cpsr |  (thumb_mode << 5);

    ir.set_reg(GuestReg.CPSR, cpsr);

    // thanks Kelpsy for this hilarious hack
    address = address & ~((thumb_mode << 1) ^ 3);
    
    ir.set_reg(GuestReg.PC, address);
    
    log_jit("Emitting bx r%d", rm);
}

static void emit_and_helper(IR* ir, GuestReg rd, IRVariable operand1, IRVariable operand2) {
    IRVariable result = operand1 & operand2;
    ir.set_flags(IRFlag.NZ, result);
    
    ir.set_reg(rd, result);
} 

static void emit_create_full_alu__THUMB()(IR* ir, Word opcode) {
    GuestReg rd = cast(GuestReg) opcode[0..2];
    GuestReg rn = cast(GuestReg) opcode[3..5];
    auto     op = opcode[6..9];

    IRVariable operand1 = ir.get_reg(rd);
    IRVariable operand2 = ir.get_reg(rn);

    // final switch (op) {
    //     case  0: emit_and_helper(ir, rd, operand1, operand2);
    // }
        // auto rd = opcode[0..2];
        // auto rm = opcode[3..5];
        // auto op = opcode[6..9];
        // Word operand1 = cpu.get_reg__thumb(rd);
        // Word operand2 = cpu.get_reg__thumb(rm);

        // final switch (op) {
        //     case  0: cpu.and!(T, true)(rd, operand1, operand2); break;
        //     case  1: cpu.eor!(T, true)(rd, operand1, operand2); break; 
        //     case  2: cpu.lsl!(T, true)(rd, operand1, operand2 & 0xFF); break;
        //     case  3: cpu.lsr!(T, true)(rd, operand1, operand2 & 0xFF); break;
        //     case  4: cpu.asr!(T, true)(rd, operand1, operand2 & 0xFF); break; 
        //     case  5: cpu.adc!(T, true)(rd, operand1, operand2); break;
        //     case  6: cpu.sbc!(T, true)(rd, operand1, operand2); break;
        //     case  7: cpu.ror!(T, true)(rd, operand1, operand2 & 0xFF); cpu.run_idle_cycle(); break;
        //     case  8: cpu.tst!(T, true)(rd, operand1, operand2); break;
        //     case  9: cpu.neg!(T, true)(rd, operand2); break;
        //     case 10: cpu.cmp!(T, true)(rd, operand1, operand2); break;
        //     case 11: cpu.cmn!(T, true)(rd, operand1, operand2); break;
        //     case 12: cpu.orr!(T, true)(rd, operand1, operand2); break;
        //     case 13: cpu.mul!(T, true)(rd, operand1, operand2); break;
        //     case 14: cpu.bic!(T, true)(rd, operand1, operand2); break;
        //     case 15: cpu.mvn!(T, true)(rd, operand2); break;
        // }
}

void decode_thumb(IR* ir, Word opcode) {
    log_jit("%x", opcode);
    decode_jumptable[opcode >> 8](ir, opcode);
}