module emu.hw.cpu.jit.backend.register_allocator;

import std.traits;

import emu.hw.cpu.jit;

import util;

enum NUM_HOST_REGS  = EnumMembers!IRHostReg.length;
enum NUM_GUEST_REGS = EnumMembers!IRGuestReg.length;

struct BindingVariable {
    IRVariable variable;
    IRHostReg  ir_host_reg;

    this(IRHostReg ir_host_reg) {
        this.ir_host_reg = ir_host_reg;
        this.bound       = false;
    }

    void bind(IRVariable new_variable) {
        if(bound) error_jit("Tried to bind %s to %s when it was already bound to %s.", host_reg, new_variable, variable);

        bound = true;
        this.variable = new_variable;
    }

    void unbind() {
        bound = false;
    }
}

final class RegisterAllocator {
    // should be enough, but can be increased if needed
    enum NUM_VARIABLES = 1024;

    IRVariable[NUM_VARIABLES] quick_variable_binding_lookup;
    BindingVariable[NUM_HOST_REGS] host_regs;
    IRHostReg[NUM_GUEST_REGS] host_to_guest_bindings;

    this() {
        reset();
    }

    void reset() {
        unbind_all();
    }

    void unbind_all() {
        for(int i = 0; i < NUM_VARIABLES; i++) {
            unbind(i);
        }
    }

    void unbind(int index) {
        variables[index].unbind();
    }

    IRHostReg get_bound_host_reg(IRVariable ir_variable) {
        if (variables[ir_variable].bound) {
            return quick_variable_binding_lookup[ir_variable].host_reg;
        } else {
            auto free_host_reg = get_free_host_reg();
            free_host_reg.bind(variables[ir_variable]);
            quick_variable_binding_lookup[ir_variable] = free_host_reg;
        }
    }

    IRHostReg get_bound_host_reg(IRGuestReg ir_variable) {
        if (variables[ir_variable].bound) {
            return quick_variable_binding_lookup[ir_variable].host_reg;
        } else {
            auto free_host_reg = get_free_host_reg();
            free_host_reg.bind(variables[ir_variable]);
            quick_variable_binding_lookup[ir_variable] = free_host_reg;
        }
    }
    
    IRHostReg get_free_host_reg() {
        for (int i = 0; i < NUM_HOST_REGS; i++) {
            if (!ir_host_regs[i].bound) {
                return ir_host_regs[i];
            }
        }
    }

    void bind_host_reg_to_guest_reg(HostReg host_reg, GuestReg guest_reg) {
        host_to_guest_bindings[guest_reg] = host_reg;
    }
}