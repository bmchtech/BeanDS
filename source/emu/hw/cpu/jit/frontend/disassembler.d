module emu.hw.cpu.jit.frontend.disassembler;

import std.sumtype;

import emu.hw.cpu.jit;
import util;

alias DecodeJumptableEntry = void function(IR ir, Word opcode);
alias DecodeJumptable = DecodeJumptableEntry[256];

bool matches(string format, uint opcode) {
    bool matches = true;

    for (int i = 0; i < format.length; i++) {
        char f = format[i];
        bool b = opcode.bit(31 - i);

        if ((f != 'x') && ((f == '1' && b != 1) || (f == '0' && b != 0))) {
            matches = false;
        }
    }

    return matches;
}

template ThumbDecoder() {
    DecodeJumptable create_decode_jumptable()() {
        DecodeJumptable decode_jumptable;

        foreach (enum i; 0 .. 256) {
            if ("11010000xxxxxxxx".matches(i)) {
                decode_jumptable[i] = &emit_branch_exchange!();
            } else

            if ("01000111xxxxxxxx".matches(i)) {
                decode_jumptable[i] = &emit_branch_exchange!();
            }
        }

        return decode_jumptable;
    }

    enum decode_jumptable = create_decode_jumptable!();

    void do_action(IR ir, Word opcode) {
        decode_jumptable[opcode >> 8](ir, opcode);
    }

    static void emit_branch_exchange()(IR ir, Word opcode) {
        IRGuestReg rm = cast(IRGuestReg) opcode[3..6];

        IROperand jump_address = ir.create_variable();
        ir.emit(IRInstructionGetReg(jump_address, rm));

        IROperand lower_bit = ir.create_variable();
        ir.emit(IRInstructionBinaryDataOp(IRBinaryDataOp.TST, lower_bit, jump_address, IROperand(1)));
        ir.emit(IRInstructionSetFlag(IRFlag.T, lower_bit));
        ir.emit(IRInstructionSetReg(IRGuestReg.PC, jump_address));

        ir.delete_variable(jump_address);
        ir.delete_variable(lower_bit);
    }
}

void decode_thumb(IR ir, Word opcode) {
    ThumbDecoder!().decode_jumptable[opcode >> 8](ir, opcode);
}