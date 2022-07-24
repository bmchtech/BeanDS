module emu.hw.cpu.jit.ir.ir;

import emu.hw.cpu.jit;

import util;

alias IR(H, G) = IRTemplate!(H, G).IR;

template IRTemplate(HostReg, GuestReg) {
    alias _IRInstruction = IRInstruction!(HostReg, GuestReg);
    alias _IRVariable    = IRVariable!(HostReg, GuestReg);
    alias _IRConstant    = IRConstant!(HostReg, GuestReg);

    alias _IRInstructionDeleteVariable = IRInstructionDeleteVariable!(HostReg, GuestReg);

    struct IR {
        // TODO: use a less awful allocator for this
        _IRInstruction[] instructions;

        IRVariableGenerator variable_generator;

        void emit(I)(I ir_opcode) {
            instructions ~= _IRInstruction(ir_opcode);
        }

        void reset() {
            instructions = [];
            variable_generator.reset();
        }

        _IRVariable create_variable() {
            return variable_generator.generate_variable();
        }

        void delete_variable(_IRVariable ir_variable) {
            emit(_IRInstructionDeleteVariable(ir_variable));
        }
    }

    struct IRVariableGenerator {
        uint counter;
        
        void reset() {
            counter = 0;
        }

        _IRVariable generate_variable() {
            return _IRVariable(counter++);
        }
    }
}