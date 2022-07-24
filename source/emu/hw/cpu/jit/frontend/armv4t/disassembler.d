module emu.hw.cpu.jit.frontend.armv4t.disassembler;

import std.sumtype;

import emu.hw.cpu.jit;
import util;

template Disassembler(HostReg, GuestReg) {
    alias _IR = IR!(HostReg, GuestReg);
    
    alias DecodeJumptableEntry = void function(_IR* ir, Word opcode);
    alias DecodeJumptable = DecodeJumptableEntry[256];

    alias _IRConstant = IRConstant!(HostReg, GuestReg);
    alias _IRGuestReg = IRGuestReg!(HostReg, GuestReg); 
    alias _IRVariable = IRVariable!(HostReg, GuestReg);

    alias _IRInstructionGetReg          = IRInstructionGetReg!(HostReg, GuestReg);
    alias _IRInstructionSetReg          = IRInstructionSetReg!(HostReg, GuestReg);
    alias _IRInstructionBinaryDataOpImm = IRInstructionBinaryDataOpImm!(HostReg, GuestReg);
    alias _IRInstructionBinaryDataOpVar = IRInstructionBinaryDataOpVar!(HostReg, GuestReg);

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
                decode_jumptable[i] = &emit_branch_exchange!();
            } else

            if ("01000111".matches(i)) {
                decode_jumptable[i] = &emit_branch_exchange!();
            }
        }

        return decode_jumptable;
    }

    enum decode_jumptable = create_decode_jumptable!();

    void do_action(_IR* ir, Word opcode) {
        decode_jumptable[opcode >> 8](ir, opcode);
    }

    static void emit_branch_exchange()(_IR* ir, Word opcode) {
        log_jit("Emitting BX");
        GuestReg rm = cast(GuestReg) opcode[3..6];

        _IRVariable temp = ir.create_variable();

        ir.emit(_IRInstructionGetReg(temp, rm));
        ir.emit(_IRInstructionSetReg(GuestReg.PC, temp));

        _IRVariable cpsr = ir.create_variable();
        
        ir.emit(_IRInstructionGetReg(cpsr, GuestReg_ARMv4T.CPSR));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, cpsr, ~(1 << 5)));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, temp, 1));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.LSL, temp, 5));
        ir.emit(_IRInstructionBinaryDataOpVar(IRBinaryDataOp.OR,  cpsr, temp));
        ir.emit(_IRInstructionSetReg(GuestReg_ARMv4T.CPSR, cpsr));

        ir.delete_variable(cpsr);
        ir.delete_variable(temp);
    }

    void decode_thumb(_IR* ir, Word opcode) {
        log_jit("%x", opcode);
        decode_jumptable[opcode >> 8](ir, opcode);
    }
}