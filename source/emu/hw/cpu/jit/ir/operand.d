module emu.hw.cpu.jit.ir.operand;

import std.typecons;

import emu.hw.cpu.jit;

abstract class IROperand_Impl {
    int resolve(IR ir, RegisterAllocator register_allocator);
}

final class IRVariable_Impl : IROperand_Impl {
    int variable_id;

    this(int variable_id) {
        this.variable_id = variable_id;
    }

    int resolve(IR ir, RegisterAllocator register_allocator) {
        return register_allocator.get_bound_host_reg(this);
    }
}

final class IRConstant_Impl : IROperand_Impl {
    int value;

    this(int value) {
        this.value = value;
    }

    int resolve(IR ir, RegisterAllocator register_allocator) {
        return value;
    }
}

final class IRGuestReg_Impl : IROperand_Impl {
    IRGuestReg guest_reg;

    this(IRGuestReg guest_reg) {
        this.id = guest_reg;
    }

    int resolve(IR ir, RegisterAllocator register_allocator) {
        IRVariable ir_variable = ir.create_variable();
        HostReg host_reg = register_allocator.get_bound_host_reg(ir_variable);
        register_allocator.bind_host_reg_to_guest_reg(host_reg, guest_reg);
        return register_allocator.get_bound_host_reg(ir_variable);
    }
}

alias IROperand = scoped!IROperand_Impl;
alias IROperand_Scope = scoped!IROperand_Impl;
alias IROperand_Scope_Scope = scoped!IROperand_Impl;
alias IROperand_Scope_Scope_Scope = scoped!IROperand_Impl;