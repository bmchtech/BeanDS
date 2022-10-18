module emu.hw.cpu.jit.ir.ir;

import emu.hw.cpu.jit;

import std.sumtype;

import util;

alias IRInstruction = SumType!(
    IRInstructionGetReg,
    IRInstructionSetReg,
    IRInstructionBinaryDataOpImm,
    IRInstructionBinaryDataOpVar,
    IRInstructionUnaryDataOp,
);

struct IR {
    // TODO: use a less awful allocator for this
    IRInstruction[] instructions;

    private void emit(I)(I ir_opcode) {
        log_jit("Emit: %s", ir_opcode);
        instructions ~= IRInstruction(ir_opcode);
    }

    void reset() {
        instructions        = [];
        current_variable_id = 0;
    }

    int current_variable_id;
    int generate_new_variable_id() {
        return current_variable_id++;
    }
    
    IRVariable generate_new_variable() {
        return IRVariable(&this, this.generate_new_variable_id());
    }

    IRVariable get_reg(GuestReg reg) {
        IRVariable variable = generate_new_variable();
        emit(IRInstructionGetReg(variable, reg));

        return variable;
    }

    void set_reg(GuestReg reg, IRVariable variable) {
        emit(IRInstructionSetReg(reg, variable));
    }

    void pretty_print() {
        for (int i = 0; i < instructions.length; i++) {
            pretty_print_instruction(instructions[i]);
        }
    }

    void pretty_print_instruction(IRInstruction instruction) {
            instruction.match!(
                (IRInstructionGetReg i)          {
                    log_ir("ld  v%d, %s", i.dest.get_id(), i.src.to_string());
                },

                (IRInstructionSetReg i)          {
                    log_ir("st  v%d, %s", i.src.get_id(), i.dest.to_string());
                },

                (IRInstructionBinaryDataOpImm i) {
                    log_ir("%s v%d, v%d, %d", i.op.to_string(), i.dest.get_id(), i.src1.get_id(), i.src2);
                },

                (IRInstructionBinaryDataOpVar i) {
                    log_ir("%s v%d, v%d, v%d", i.op.to_string(), i.dest.get_id(), i.src1.get_id(), i.src2.get_id());
                },

                (IRInstructionUnaryDataOp i)     {
                    log_ir("%s v%d, v%d", i.op.to_string(), i.dest.get_id(), i.src.get_id());
                }
            );
    }
}

struct IRVariable {
    // Note that these are static single assignment variables, which means that
    // they can only be assigned to once. Any attempt to mutate an IRVariable
    // after it has been assigned to will result in a new variable being created
    // and returned. 

    private int variable_id;
    private IR* ir;

    @disable this();

    this(IR* ir, int variable_id) {
        this.variable_id = variable_id;
        this.ir          = ir;
    }

    IRVariable opBinary(string s)(IRVariable other) {
        IRVariable dest = ir.generate_new_variable();

        IRBinaryDataOp op = get_binary_data_op!s;
        ir.emit(IRInstructionBinaryDataOpVar(op, dest, this, other));

        return dest;
    }

    IRVariable opBinary(string s)(int other) {
        IRVariable dest = ir.generate_new_variable();

        IRBinaryDataOp op = get_binary_data_op!s;
        ir.emit(IRInstructionBinaryDataOpImm(op, dest, this, other));

        return dest;
    }

    // TODO: figure out how to make this work
    // @disable IRVariable opBinaryRight(string s)(IRVariable other);
    // @disable IRVariable opBinaryRight(string s)(int other);
    
    // IRVariable opBinaryRight(string s)(IRVariable other) {
    //     return other.opBinary!s(this);
    // }

    // IRVariable opBinaryRight(string s)(int other) {
    //     return this.opBinary!s(other);
    // }

    // void opOpAssign(string s)(IRVariable other) {

    // }

    // void opOpAssign(string s)(int other) {
    //     this.variable_id = ir.generate_new_variable_id();
    //     ir.emit(IRInstructionUnaryDataOp(IRUnaryDataOp.MOV, this, rhs));
    // }
    
    void opAssign(IRVariable rhs) {
        this.variable_id = ir.generate_new_variable_id();
        ir.emit(IRInstructionUnaryDataOp(IRUnaryDataOp.MOV, this, rhs));
    }

    IRVariable opUnary(string s)() {
        IRVariable dest = ir.generate_new_variable();

        IRUnaryDataOp op = get_unary_data_op!s;
        ir.emit(IRInstructionUnaryDataOp(op, dest, this));

        return dest;
    }

    IRBinaryDataOp get_binary_data_op(string s)() {
        log_jit("get_binary_data_op: %s", s);
        final switch (s) {
            case "+":  return IRBinaryDataOp.ADD;
            case "-":  return IRBinaryDataOp.SUB;
            case "<<": return IRBinaryDataOp.LSL;
            case "|":  return IRBinaryDataOp.ORR;
            case "&":  return IRBinaryDataOp.AND;
            case "^":  return IRBinaryDataOp.XOR;
        }
    }

    IRUnaryDataOp get_unary_data_op(string s)() {
        final switch (s) {
            case "-": return IRUnaryDataOp.NEG;
            case "~": return IRUnaryDataOp.NOT;
        }
    }

    int get_id() {
        return variable_id;
    }
}

struct IRConstant {
    int value;
}

struct IRGuestReg {
    GuestReg guest_reg;
}

struct IRInstructionBinaryDataOpImm {
    IRBinaryDataOp op;

    IRVariable dest;
    IRVariable src1;
    uint src2;
}

struct IRInstructionBinaryDataOpVar {
    IRBinaryDataOp op;

    IRVariable dest;
    IRVariable src1;
    IRVariable src2;
}

struct IRInstructionUnaryDataOp {
    IRUnaryDataOp op;

    IRVariable dest;
    IRVariable src;
}

struct IRInstructionGetReg {
    IRVariable dest;
    GuestReg src;
}

struct IRInstructionSetReg{
    GuestReg dest;
    IRVariable src;
}