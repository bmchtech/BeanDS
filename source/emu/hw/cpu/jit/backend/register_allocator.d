module emu.hw.cpu.jit.backend.register_allocator;

import emu.hw.cpu.jit;
import std.traits;
import std.typecons;
import util;

final class RegisterAllocator(HostReg) {
    struct BindingVariable {
        HostReg host_reg;

        int variable;
        bool variable_bound;

        GuestReg guest_reg;
        bool guest_reg_bound;

        this(HostReg host_reg) {
            this.host_reg = host_reg;
            unbind_all();
        }

        void bind_variable(IRVariable new_variable) {
            if (variable_bound) error_jit("Tried to bind %s to %s when it was already bound to %s.", host_reg, new_variable, variable);

            log_jit("Binding %s to %s.", host_reg, new_variable);
            variable_bound = true;
            this.variable = new_variable.get_id();
            log_jit("%s is %s", host_reg, this.variable);
        }

        void bind_guest_reg(GuestReg new_guest_reg) {
            if (guest_reg_bound) error_jit("Tried to bind %s to %s when it was already bound to %s.", host_reg, new_guest_reg, guest_reg);

            log_jit("Binding %s to %s.", host_reg, new_guest_reg);
            guest_reg_bound = true;
            this.guest_reg = new_guest_reg;
        }

        void unbind_variable() {
            variable_bound = false;
        }

        void unbind_guest_reg() {
            guest_reg_bound = false;
        }

        void unbind_all() {
            unbind_variable();
            unbind_guest_reg();
        }

        bool unbound() {
            return !variable_bound && !guest_reg_bound;
        }
    }

    enum HOST_REGS  = EnumMembers!HostReg;
    enum GUEST_REGS = EnumMembers!GuestReg;

    enum NUM_HOST_REGS  = HOST_REGS.length;
    enum NUM_GUEST_REGS = GUEST_REGS.length;

    // should be enough, but can be increased if needed
    enum NUM_VARIABLES = 1024;

    BindingVariable[NUM_HOST_REGS] bindings;

    this() {
        log_jit("Initializing register allocator.");
        
        for (int i = 0; i < NUM_HOST_REGS; i++) {
            bindings[i] = BindingVariable(cast(HostReg) i);
        }
        
        reset();
    }

    void reset() {
        unbind_all();
    }

    void unbind_all() {
        for(int i = 0; i < NUM_HOST_REGS; i++) {
            log_jit("unbinding all");
            bindings[i].unbind_all();
        }
    }

    HostReg get_bound_host_reg(IRVariable ir_variable) {
        BindingVariable* binding_variable;
        int binding_variable_index = get_binding_variable_from_variable(ir_variable);

        if (binding_variable_index == -1) {
            binding_variable = get_free_binding_variable();
            log_jit("wtf1 %d",bindings[1].variable);
            binding_variable.bind_variable(ir_variable);
            log_jit("wtf1 %d",bindings[1].variable);
        } else {
            binding_variable = &bindings[binding_variable_index];
        }

            log_jit("wtf1 %d",bindings[1].variable);
        return binding_variable.host_reg;
    }

    HostReg get_bound_host_reg(GuestReg guest_reg) {
        BindingVariable* binding_variable;
        int binding_variable_index = get_binding_variable_from_guest_reg(guest_reg);

        if (binding_variable_index == -1) {
            binding_variable = get_free_binding_variable();
            binding_variable.bind_guest_reg(guest_reg);
        } else {
            binding_variable = &bindings[binding_variable_index];
        }

        return binding_variable.host_reg;
    }

    void bind_variable_to_host_reg(IRVariable ir_variable, HostReg host_reg) {
        bindings[host_reg].bind_variable(ir_variable);
    }

    void bind_host_reg_to_guest_reg(HostReg host_reg, GuestReg guest_reg) {
        bindings[host_reg].bind_guest_reg(guest_reg);
    }

    int get_binding_variable_from_variable(IRVariable ir_variable) {
        for (int i = 0; i < NUM_HOST_REGS; i++) {
            BindingVariable binding_variable = bindings[i];
            log_jit("Comparing %d [%s] to %s. [%d]", binding_variable.variable, binding_variable.host_reg, ir_variable, !binding_variable.unbound());
            if (!binding_variable.unbound() && binding_variable.variable == ir_variable.get_id()) {
                return i;
            }
        }

        return -1;
    }

    int get_binding_variable_from_guest_reg(GuestReg guest_reg) {
        for (int i = 0; i < NUM_HOST_REGS; i++) {
            BindingVariable binding_variable = bindings[i];
            if (!binding_variable.unbound() && binding_variable.guest_reg == guest_reg) {
                log_jit("getting binding variable from guest reg %s", guest_reg);
                return i;
            }
        }

        return -1;
    }

    void maybe_unbind_variable(IRVariable ir_variable, int last_emitted_ir_instruction) {
        if (ir_variable.get_lifetime_end() < last_emitted_ir_instruction) {
            error_jit("Used an IRVariable v%d on IR Instruction #%d while its lifetime has already ended on IR Instruction #%d.", ir_variable.get_id(), last_emitted_ir_instruction, ir_variable.get_lifetime_end());
        }

        if (ir_variable.get_lifetime_end() == last_emitted_ir_instruction) {
            unbind_variable(ir_variable);
        }
    }

    void unbind_variable(IRVariable ir_variable) {
        log_jit("Unbinding v%d.", ir_variable.get_id());
        auto binding_variable_index = get_binding_variable_from_variable(ir_variable);
        if (binding_variable_index == -1) error_jit("Tried to unbind %s when it was not bound.", ir_variable);
        bindings[binding_variable_index].unbind_variable();
    }

    void unbind_host_reg(HostReg host_reg) {
        bindings[host_reg].unbind_all();
    }

    bool will_variable_be_unbound(IRVariable ir_variable, int last_emitted_ir_instruction) {
        return ir_variable.get_lifetime_end() == last_emitted_ir_instruction;
    }

    void unbind_guest_reg(GuestReg guest_reg) {
        auto binding_variable_index = get_binding_variable_from_guest_reg(guest_reg);
        if (binding_variable_index == -1) error_jit("Tried to unbind %s when it was not bound.", guest_reg);
        bindings[binding_variable_index].unbind_guest_reg();
    }
    
    private BindingVariable* get_free_binding_variable() {
        log_jit("Getting free binding variable.");
        for (int i = 0; i < NUM_HOST_REGS; i++) {
            // pls dont clobber the stack pointer
            static if (is(HostReg == HostReg_x86_64)) {
                if (bindings[i].host_reg == HostReg_x86_64.ESP || bindings[i].host_reg == HostReg_x86_64.EDI) continue;
            }

            if (bindings[i].unbound()) {
                return &bindings[i];
            }
        }

        error_jit("No free binding variable found.");
        return &bindings[0]; // doesn't matter, error anyway
    }
}