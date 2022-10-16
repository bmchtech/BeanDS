module emu.hw.cpu.jit.ir.ir;

import emu.hw.cpu.jit;

import std.sumtype;

import util;

alias IRInstruction = SumType!(
    IRInstructionGetReg,
    IRInstructionSetReg,
    IRInstructionBinaryDataOpImm,
    IRInstructionBinaryDataOpVar,
    IRInstructionDeleteVariable,
    IRInstructionUnaryDataOp,
);

struct IR {
    // TODO: use a less awful allocator for this
    IRInstruction[] instructions;

    IRVariableGenerator variable_generator;

    void emit(I)(I ir_opcode) {
        log_jit("Emit: %s", ir_opcode);
        instructions ~= IRInstruction(ir_opcode);
    }

    void reset() {
        instructions = [];
        variable_generator.reset();
    }

    IRVariable create_variable() {
        return variable_generator.generate_variable(&this);
    }

    void delete_variable(IRVariable ir_variable) {
        emit(IRInstructionDeleteVariable(ir_variable));
    }
}

struct IRVariable {
    int variable_id;
    IR* ir;

    this(IR* ir, int variable_id) {
        this.variable_id = variable_id;
        this.ir          = ir;
    }

    int get_id() {
        return variable_id;
    }

    IRVariable opBinary(string s)(IRVariable other) {
        IRBinaryDataOp op = get_binary_data_op!s;
        ir.emit(IRInstructionBinaryDataOpVar(op, this, other));
        return this;
    }

    IRVariable opBinary(string s)(int other) {
        IRBinaryDataOp op = get_binary_data_op!s;
        log_jit("fucking emit already");
        ir.emit(IRInstructionBinaryDataOpImm(op, this, other));
        return this;
    }

    IRBinaryDataOp get_binary_data_op(string s)() {
        final switch (s) {
            case "+":  return IRBinaryDataOp.ADD;
            case "-":  return IRBinaryDataOp.SUB;
            case "<<": return IRBinaryDataOp.LSL;
            case "|":  return IRBinaryDataOp.OR;
            case "&":  return IRBinaryDataOp.AND;
        }
    }
    
    void opAssign(IRVariable rhs) {
        ir.emit(IRInstructionBinaryDataOpVar(IRBinaryDataOp.MOV, this, rhs));
    }

    IRVariable opUnary(string s)() {
        IRUnaryDataOp op = get_unary_data_op!s;
        ir.emit(IRInstructionUnaryDataOp(op, this));
        return this;
    }

    IRUnaryDataOp get_unary_data_op(string s)() {
        final switch (s) {
            case "-": return IRUnaryDataOp.NEG;
            case "~": return IRUnaryDataOp.NOT;
        }
    }
}

struct IRConstant {
    int value;

    this(int value) {
        this.value = value;
    }
}

struct IRGuestReg {
    GuestReg guest_reg;

    this(GuestReg guest_reg) {
        this.guest_reg = guest_reg;
    }
}

struct IRVariableGenerator {
    uint counter;
    
    void reset() {
        counter = 0;
    }

    IRVariable generate_variable(IR* ir) {
        return IRVariable(ir, counter++);
    }
}

struct IRInstructionGetReg {
    IRVariable dest;
    GuestReg src;
}

struct IRInstructionSetReg{
    GuestReg dest;
    IRVariable src;
}

struct IRInstructionBinaryDataOpImm {
    IRBinaryDataOp op;
    IRVariable dest;
    uint src;
}

struct IRInstructionBinaryDataOpVar {
    IRBinaryDataOp op;
    IRVariable dest;
    IRVariable src;
}

struct IRInstructionDeleteVariable {
    IRVariable variable;
}

struct IRInstructionUnaryDataOp {
    IRUnaryDataOp op;
    IRVariable dest;
}