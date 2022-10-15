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
    alias _IRInstructionUnaryDataOp     = IRInstructionUnaryDataOp!(HostReg, GuestReg);

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
            }
        }

        return decode_jumptable;
    }

    enum decode_jumptable = create_decode_jumptable!();

    void do_action(_IR* ir, Word opcode) {
        decode_jumptable[opcode >> 8](ir, opcode);
    }

    static void emit_branch_exchange__THUMB()(_IR* ir, Word opcode) {
        GuestReg rm = cast(GuestReg) opcode[3..6];

        log_jit("Emitting bx r%d", rm);

        _IRVariable new_pc_value = ir.create_variable();

        ir.emit(_IRInstructionGetReg(new_pc_value, rm));
        if (rm == 15) ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.SUB, new_pc_value, 2));

        _IRVariable temp = ir.create_variable();
        _IRVariable cpsr = ir.create_variable();
        
        ir.emit(_IRInstructionGetReg(cpsr, GuestReg_ARMv4T.CPSR));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, cpsr, ~(1 << 5)));
        ir.emit(_IRInstructionBinaryDataOpVar(IRBinaryDataOp.MOV, temp, new_pc_value));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, temp, 1));

        _IRVariable pc_aligner = ir.create_variable();
        ir.emit(_IRInstructionBinaryDataOpVar(IRBinaryDataOp.MOV, pc_aligner, temp));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.LSL, pc_aligner, 1));
        ir.emit(_IRInstructionUnaryDataOp(IRUnaryDataOp.NEG, pc_aligner));         
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.ADD, pc_aligner, 3));
        ir.emit(_IRInstructionUnaryDataOp(IRUnaryDataOp.NOT, pc_aligner));        
        ir.emit(_IRInstructionBinaryDataOpVar(IRBinaryDataOp.AND, new_pc_value, pc_aligner));
        ir.emit(_IRInstructionSetReg(GuestReg.PC, new_pc_value));

        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.LSL, temp, 5));
        ir.emit(_IRInstructionBinaryDataOpVar(IRBinaryDataOp.OR,  cpsr, temp));
        ir.delete_variable(temp);

        ir.emit(_IRInstructionSetReg(GuestReg_ARMv4T.CPSR, cpsr));
        ir.delete_variable(cpsr);
        ir.delete_variable(new_pc_value);
        ir.delete_variable(pc_aligner);
    }

    static void emit_branch__ARM()(_IR* ir, Word opcode) {

        // set linkage register?
        if (opcode[24]) {
            _IRVariable lr_value = ir.create_variable();
            ir.emit(_IRInstructionGetReg(lr_value, GuestReg_ARMv4T.PC));
            ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.SUB, lr_value, 4));
            ir.emit(_IRInstructionSetReg(lr_value, GuestReg_ARMv4T.LR));
        }

        Word offset = sext_32(opcode[0..23], 24) * 4;

        log_jit("Emitting b 0x%x", cast(int) offset);

        _IRVariable new_pc = ir.create_variable();
        ir.emit(_IRInstructionGetReg(new_pc, GuestReg_ARMv4T.PC));
        ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.ADD, new_pc, offset));
        ir.emit(_IRInstructionSetReg(new_pc, GuestReg_ARMv4T.PC));
    }

    static void create_clz__ARM()(_IR* ir, Word opcode) {

        GuestReg rm = cast(GuestReg) opcode[0 .. 3];
        GuestReg rd = cast(GuestReg) opcode[16..20];

        log_jit("Emitting clz r%d, r%d", rd, rm);

        _IRVariable operand = ir.create_variable();
        ir.emit(_IRInstructionGetReg(operand, rm));
        ir.emit(_IRInstructionUnaryDataOp(IRUnaryDataOp.CLZ, operand));
        ir.emit(_IRInstructionSetReg(operand, rd));
    }

    static void create_swap__ARM()(_IR* ir, Word opcode) {
        GuestReg rm = cast(GuestReg) opcode[0.. 3];
        GuestReg rd = cast(GuestReg) opcode[12..15];
        GuestReg rn = cast(GuestReg) opcode[16..19];

        log_jit("Emitting swp%s r%d, r%d, r%d", opcode[22] ? "b" : "", rd, rm, rn);

        _IRVariable address = ir.create_variable();
        ir.emit(_IRInstructionGetReg(address, rn));

        _IRVariable read_value    = ir.create_variable();
        _IRVariable written_value = ir.create_variable();

        // byte swap?
        if (opcode[22]) {
            ir.emit(_IRInstructionReadByte(address, read_value));
            ir.emit(_IRInstructionGetReg(written_value, rm));
            ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, 0xFF));
            ir.emit(_IRInstructionWriteByte(address, written_value));
        } else {
            ir.emit(_IRInstructionReadWord(address, read_value));
            ir.emit(_IRInstructionGetReg(written_value, rm));
            ir.emit(_IRInstructionWriteWord(address, written_value));
        }

        ir.emit(_IRInstructionSetReg(rd, read_value));
    }

    void decode_thumb(_IR* ir, Word opcode) {
        log_jit("%x", opcode);
        decode_jumptable[opcode >> 8](ir, opcode);
    }
}