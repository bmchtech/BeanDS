module emu.hw.cpu.jit.backend.x86_64.emitter;

import std.sumtype;

import xbyak;

import emu.hw.cpu.jit;
import util;

template Emitter(HostReg) {
    final class Code : CodeGenerator {
        alias _RegisterAllocator            = RegisterAllocator!(HostReg);

        _RegisterAllocator register_allocator;

        this() {
            log_jit("initializing code emitter");
            register_allocator = new _RegisterAllocator();
        }

        void disambiguate_second_operand_and_emit(string op)(Reg reg, IROperand operand) {
            // static if (T == operand)

            // ir_operand.match!(
            //     (_IRVariable ir_variable) => ir_variable,

            //     (_IRConstant ir_constant) {
            //         error_jit("Tried to get variable from constant");
            //         return _IRVariable(-1);
            //     },

            //     (_IRGuestReg ir_guest_reg) {
            //         error_jit("Tried to get variable from guest register");
            //         return _IRVariable(-1);
            //     }
            // );
        }

        override void reset() {
            super.reset();
            
            if (register_allocator) register_allocator.reset();
        }

        void emit(IR* ir) {
            emit_prologue();

            for (int i = 0; i < ir.instructions.length; i++) {
                emit(ir.instructions[i]);
            }

            emit_epilogue();
        }

        void emit_prologue() {
            push(rbp);
            mov(rbp, rsp);
            
            push(rbx);
            push(rsi);
            push(rdi);
            push(r8);
            push(r9);
            push(r10);
            push(r11);
            push(r12);
            push(r13);
            push(r14);
            push(r15);
        }

        void emit_epilogue() {
            pop(r15);
            pop(r14);
            pop(r13);
            pop(r12);
            pop(r11);
            pop(r10);
            pop(r9);
            pop(r8);
            pop(rdi);
            pop(rsi);
            pop(rbx);

            pop(rbp);

            ret();
        }

        void emit_GET_REG(IRInstructionGetReg ir_instruction) {
            log_jit("emitting get_reg");

            GuestReg guest_reg = ir_instruction.src;
            log_jit("wtf %d",register_allocator.bindings[1].variable);
            HostReg host_reg = register_allocator.get_bound_host_reg(ir_instruction.dest);
            log_jit("wtf %d",register_allocator.bindings[1].variable);
            register_allocator.bind_host_reg_to_guest_reg(host_reg, guest_reg);
            log_jit("wtf %d",register_allocator.bindings[1].variable);

            int offset = cast(int) JITState.regs.offsetof + 4 * guest_reg;
            mov(host_reg.to_xbyak_reg32(), dword [rdi + offset]);
        }

        void emit_DELETE_VARIABLE(IRInstructionDeleteVariable ir_instruction) {
            log_jit("emitting delete_variable");
            register_allocator.unbind_variable(ir_instruction.variable);
        }

        void emit_SET_REG(IRInstructionSetReg ir_instruction) {
            log_jit("emitting set_reg");

            GuestReg dest_reg = ir_instruction.dest;
            Reg src_reg = register_allocator.get_bound_host_reg(ir_instruction.src).to_xbyak_reg32();
            
            int offset = cast(int) JITState.regs.offsetof + 4 * dest_reg;
            mov(dword [rdi + offset], src_reg);
        }

        void emit_BINARY_DATA_OP_IMM(IRInstructionBinaryDataOpImm ir_instruction) {
            log_jit("emitting binary_data_op_imm");

            Reg dest_reg = register_allocator.get_bound_host_reg(ir_instruction.dest).to_xbyak_reg32();
            int src_imm  = ir_instruction.src;
            
            switch (ir_instruction.op) {
                case IRBinaryDataOp.AND:
                    and(dest_reg, src_imm);
                    break;
                
                case IRBinaryDataOp.OR:
                    or(dest_reg, src_imm);
                    break;
                
                case IRBinaryDataOp.LSL:
                    shl(dest_reg, src_imm);
                    break;
                
                case IRBinaryDataOp.ADD:
                    add(dest_reg, src_imm);
                    break;
                
                case IRBinaryDataOp.SUB:
                    sub(dest_reg, src_imm);
                    break;
                
                default: break;
            }
        }

        void emit_BINARY_DATA_OP_VAR(IRInstructionBinaryDataOpVar ir_instruction) {
            log_jit("emitting binary_data_op_var");

            Reg dest_reg = register_allocator.get_bound_host_reg(ir_instruction.dest).to_xbyak_reg32();
            HostReg src_var  = register_allocator.get_bound_host_reg(ir_instruction.src);

            switch (ir_instruction.op) {
                case IRBinaryDataOp.AND:
                    and(dest_reg, src_var.to_xbyak_reg32());
                    break;
                
                case IRBinaryDataOp.OR:
                    or(dest_reg, src_var.to_xbyak_reg32());
                    break;
                
                case IRBinaryDataOp.LSL:
                    shl(dest_reg, src_var.to_xbyak_reg8());
                    break;
                
                case IRBinaryDataOp.ADD:
                    add(dest_reg, src_var.to_xbyak_reg32());
                    break;
                
                case IRBinaryDataOp.SUB:
                    sub(dest_reg, src_var.to_xbyak_reg32());
                    break;
                
                case IRBinaryDataOp.MOV:
                    mov(dest_reg, src_var.to_xbyak_reg32());
                    break;
                
                default: break;
            }
        }

        void emit_UNARY_DATA_OP(IRInstructionUnaryDataOp ir_instruction) {
            log_jit("emitting unary_data_op");

            Reg dest_reg = register_allocator.get_bound_host_reg(ir_instruction.dest).to_xbyak_reg32();

            switch (ir_instruction.op) {
                case IRUnaryDataOp.NOT:
                    not(dest_reg);
                    break;

                case IRUnaryDataOp.NEG:
                    neg(dest_reg);
                    break;

                default: break;
            }
        }

        void emit(IRInstruction ir_instruction) {
            ir_instruction.match!(
                (IRInstructionGetReg i)          => emit_GET_REG(i),
                (IRInstructionSetReg i)          => emit_SET_REG(i),
                (IRInstructionDeleteVariable i)  => emit_DELETE_VARIABLE(i),
                (IRInstructionBinaryDataOpImm i) => emit_BINARY_DATA_OP_IMM(i),
                (IRInstructionBinaryDataOpVar i) => emit_BINARY_DATA_OP_VAR(i),
                (IRInstructionUnaryDataOp i)     => emit_UNARY_DATA_OP(i),
            );
        }
    }
}