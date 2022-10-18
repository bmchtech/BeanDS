module emu.hw.cpu.jit.frontend.armv4t.disassembler;

import std.sumtype;

import emu.hw.cpu.jit;
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
    
    cpsr = cpsr & ~(1          << 5);
    cpsr = cpsr |  (thumb_mode << 5);

    ir.set_reg(GuestReg.CPSR, cpsr);

    // thanks Kelpsy for this hilarious hack
    address = address & ~((thumb_mode << 1) ^ 3);
    
    ir.set_reg(GuestReg.PC, address);
}


//  Reg rm = opcode[3..6];

//             Word address = cpu.get_reg(rm);
//             cpu.set_flag(Flag.T, cast(bool) (address & 1));
//             cpu.set_reg(pc, address);
    // log_jit("Emitting bx r%d", rm);

    // IRVariable new_pc_value = ir.create_variable();

    // ir.emit(IRInstructionGetReg(new_pc_value, rm));
    // if (rm == 15) ir.emit(IRInstructionBinaryDataOpImm(IRBinaryDataOp.SUB, new_pc_value, 2));

    // IRVariable temp = ir.create_variable();
    // IRVariable cpsr = ir.create_variable();
    // IRVariable pc_aligner = ir.create_variable();
    
    // ir.emit(IRInstructionGetReg(cpsr, GuestReg.CPSR));

    // // cpsr = cpsr & ~(1 << 5);
    // // temp = new_pc_value;
    // // temp = temp & 1;
    // // pc_aligner = temp;
    // // new_pc_value = new_pc_value & ~((pc_aligner << 1) + 3);

    // ir.emit(IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, cpsr, ~(1 << 5)));
    // ir.emit(IRInstructionBinaryDataOpVar(IRBinaryDataOp.MOV, temp, new_pc_value));
    // ir.emit(IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, temp, 1));

    // ir.emit(IRInstructionBinaryDataOpVar(IRBinaryDataOp.MOV, pc_aligner, temp));
    // ir.emit(IRInstructionBinaryDataOpImm(IRBinaryDataOp.LSL, pc_aligner, 1));
    // ir.emit(IRInstructionUnaryDataOp(IRUnaryDataOp.NEG, pc_aligner));         
    // ir.emit(IRInstructionBinaryDataOpImm(IRBinaryDataOp.ADD, pc_aligner, 3));
    // ir.emit(IRInstructionUnaryDataOp(IRUnaryDataOp.NOT, pc_aligner));        
    // ir.emit(IRInstructionBinaryDataOpVar(IRBinaryDataOp.AND, new_pc_value, pc_aligner));
    // ir.emit(IRInstructionSetReg(GuestReg.PC, new_pc_value));

    // cpsr = cpsr | (temp << 5);

    // ir.delete_variable(temp);

    // ir.emit(IRInstructionSetReg(GuestReg.CPSR, cpsr));

    // ir.delete_variable(cpsr);
    // ir.delete_variable(new_pc_value);
    // ir.delete_variable(pc_aligner);
// }

// static void emit_conditional_branch__THUMB()(IR* ir, Word opcode) {
//     switch (cond) {
//         case 0x0: return ( get_flag(Flag.Z));
//         case 0x1: return (!get_flag(Flag.Z));
//         case 0x2: return ( get_flag(Flag.C));
//         case 0x3: return (!get_flag(Flag.C));
//         case 0x4: return ( get_flag(Flag.N));
//         case 0x5: return (!get_flag(Flag.N));
//         case 0x6: return ( get_flag(Flag.V));
//         case 0x7: return (!get_flag(Flag.V));
//         case 0x8: return ( get_flag(Flag.C) && !get_flag(Flag.Z));
//         case 0x9: return (!get_flag(Flag.C) ||  get_flag(Flag.Z));
//         case 0xA: return ( get_flag(Flag.N) ==  get_flag(Flag.V));
//         case 0xB: return ( get_flag(Flag.N) !=  get_flag(Flag.V));
//         case 0xC: return (!get_flag(Flag.Z) && (get_flag(Flag.N) == get_flag(Flag.V)));
//         case 0xD: return ( get_flag(Flag.Z) || (get_flag(Flag.N) != get_flag(Flag.V)));
//         case 0xE: return true;
//         case 0xF: error_arm7("ARM7 opcode has a condition of 0xF"); return false;

//         default: assert(0);
//     }
// }

// static void emit_branch__ARM()(_IR* ir, Word opcode) {

//     // set linkage register?
//     if (opcode[24]) {
//         _IRVariable lr_value = ir.create_variable();
//         ir.emit(_IRInstructionGetReg(lr_value, GuestReg_ARMv4T.PC));
//         ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.SUB, lr_value, 4));
//         ir.emit(_IRInstructionSetReg(lr_value, GuestReg_ARMv4T.LR));
//     }

//     Word offset = sext_32(opcode[0..23], 24) * 4;

//     log_jit("Emitting b 0x%x", cast(int) offset);

//     _IRVariable new_pc = ir.create_variable();
//     ir.emit(_IRInstructionGetReg(new_pc, GuestReg_ARMv4T.PC));
//     ir.emit(_IRInstructionBinaryDataOpImm(IRBinaryDataOp.ADD, new_pc, offset));
//     ir.emit(_IRInstructionSetReg(new_pc, GuestReg_ARMv4T.PC));
// }

// static void create_clz__ARM()(_IR* ir, Word opcode) {

//     GuestReg rm = cast(GuestReg) opcode[0 .. 3];
//     GuestReg rd = cast(GuestReg) opcode[16..20];

//     log_jit("Emitting clz r%d, r%d", rd, rm);

//     _IRVariable operand = ir.create_variable();
//     ir.emit(_IRInstructionGetReg(operand, rm));
//     ir.emit(_IRInstructionUnaryDataOp(IRUnaryDataOp.CLZ, operand));
//     ir.emit(_IRInstructionSetReg(operand, rd));
// }

// static void create_swap__ARM()(_IR* ir, Word opcode) {
//     GuestReg rm = cast(GuestReg) opcode[0.. 3];
//     GuestReg rd = cast(GuestReg) opcode[12..15];
//     GuestReg rn = cast(GuestReg) opcode[16..19];

//     log_jit("Emitting swp%s r%d, r%d, r%d", opcode[22] ? "b" : "", rd, rm, rn);

//     IRVariable address = ir.create_variable();
//     ir.emit(_IRInstructionGetReg(address, rn));

//     IRVariable read_value    = ir.create_variable();
//     IRVariable written_value = ir.create_variable();

//     // byte swap?
//     if (opcode[22]) {
//         ir.emit(IRInstructionReadByte(address, read_value));
//         ir.emit(IRInstructionGetReg(written_value, rm));
//         ir.emit(IRInstructionBinaryDataOpImm(IRBinaryDataOp.AND, 0xFF));
//         ir.emit(IRInstructionWriteByte(address, written_value));
//     } else {
//         ir.emit(IRInstructionReadWord(address, read_value));
//         ir.emit(IRInstructionGetReg(written_value, rm));
//         ir.emit(IRInstructionWriteWord(address, written_value));
//     }

//     ir.emit(IRInstructionSetReg(rd, read_value));
// }

void decode_thumb(IR* ir, Word opcode) {
    log_jit("%x", opcode);
    decode_jumptable[opcode >> 8](ir, opcode);
}