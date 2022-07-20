module emu.hw.cpu.jit.backend.emitter;

import xbyak;

template Emitter(HostReg, GuestReg) {
    final class Code : CodeGenerator {}

    RegisterAllocator register_allocator;
    Code code;

    void emit_GET_REG(IRInstructionGetReg ir_instruction) {
        auto host_reg = register_allocator.get_bound_host_reg(ir_instruction.dest.get_variable());
        register_allocator.bind_host_reg_to_guest_reg(host_reg, ir_instruction.guest_reg);
    }

    void emit_DELETE_VARIABLE(IRInstructionDeleteVariable ir_instruction) {
        register_allocator.delete_variable(ir_instruction.variable);
    }

    void emit_SET_REG(IRInstructionSetReg ir_instruction) {
        IRHostReg dest_reg = register_allocator.get_bound_host_reg(ir_instruction.dest.get_variable());
        IRHostReg src_reg = ir_instruction.src.resolve();
        code.mov(host_reg, src_reg);
    }

    void emit_SET_FLAG(IRInstructionSetFlag ir_instruction) {
        
    }

    void do_action(IRInstruction ir_instruction) {
        // yes switch on type is an antipattern but D doesnt allow inheritance w/o heap allocation
        // i can't tank that performance hit for a jit, so this is what we're doing instead. i could
        // also put these emit functions within the various instruction types but honestly, i'd rather
        // have all the emit code in one spot and leave the instruction type definitions to a bare minimum.
        // y'know, rust trait style.

        // i cannot get over how ugly it looks though
        // i'm sorry.
            
        final switch (ir_instruction.type) {
            case IRInstructionType.GET_REG:
                emit_GET_REG(ir_instruction.inner.ir_instruction_get_reg);
                break;
            case IRInstructionType.SET_REG:
                emit_SET_REG(ir_instruction.inner.ir_instruction_set_reg);
                break;
            case IRInstructionType.EVAL_COND:
                // emit_EVAL_COND(ir_instruction.inner.ir_instruction_eval_cond);
                break;
            case IRInstructionType.BINARY_DATA_OP:
                // emit_BINARY_DATA_OP(ir_instruction.inner.ir_instruction_binary_data_op);
                break;
            case IRInstructionType.SET_FLAG:
                emit_SET_FLAG(ir_instruction.inner.ir_instruction_set_flag);
                break;
            case IRInstructionType.DELETE_VARIABLE:
                emit_DELETE_VARIABLE(ir_instruction.inner.ir_instruction_delete_variable);
                break;
        }
    }
}