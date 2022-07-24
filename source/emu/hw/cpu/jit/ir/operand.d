module emu.hw.cpu.jit.ir.operand;

import std.sumtype;

import emu.hw.cpu.jit;

import util;

alias IRVariable(H, G) = IROperandTemplate!(H, G).IRVariable;
alias IRConstant(H, G) = IROperandTemplate!(H, G).IRConstant;
alias IRGuestReg(H, G) = IROperandTemplate!(H, G).IRGuestReg;

template IROperandTemplate(HostReg, GuestReg) {
    alias _IR = IR!(HostReg, GuestReg);
    alias _RegisterAllocator = RegisterAllocator!(HostReg, GuestReg);

    struct IRVariable {
        int variable_id;

        this(int variable_id) {
            this.variable_id = variable_id;
        }

        int get_id() {
            return variable_id;
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
}