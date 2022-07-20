module emu.hw.cpu.jit.ir.ir;

import util;

alias IROperandInner = IROperand.IROperandInner;
alias IRVariable     = IROperand.IROperandInner.IRVariable;
alias IRConstant     = IROperand.IROperandInner.IRConstant;

struct IR {
    // TODO: use a less awful allocator for this
    IRInstruction[] instructions;

    IRVariableGenerator variable_generator;

    void emit(I)(I ir_opcode) {
        instructions ~= IRInstruction(ir_opcode);
    }

    void reset() {
        variable_generator.reset();
    }

    IRVariable create_variable() {
        return variable_generator.generate_variable();
    }

    void delete_variable(IROperand ir_operand) {
        emit(IRInstructionDeleteVariable(ir_operand.get_variable()));
    }
}

struct IRVariableGenerator {
    uint counter;
    
    void reset() {
        counter = 0;
    }

    IRVariable generate_variable() {
        return IRVariable(counter++);
    }
}