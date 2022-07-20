module emu.hw.cpu.jit.ir.instruction;

import std.typecons;

import emu.hw.cpu.jit;

abstract class IRInstruction_Impl {
    void do_action() {

    }
} 

final class IrInstructionGetReg_Impl : IRInstruction_Impl {
    IROperand dest;
    IRGuestReg src;

    this(IROperand dest, IRGuestReg src) {
        this.dest = dest;
        this.src = src;
    }
}

final class IrInstructionSetReg_Impl : IRInstruction_Impl {
    IRGuestReg dest;
    IROperand src;

    this(IRGuestReg dest, IROperand src) {
        this.dest = guestdest_reg;
        this.src = src;
    }
}

final class IrInstructionEvalCond_Impl : IRInstruction_Impl {
    IROperand dest;
    IRCond cond;

    this(IROperand dest, IRCond cond) {
        this.dest = dest;
        this.cond = cond;
    }
}

final class IrInstructionBinaryDataOp_Impl : IRInstruction_Impl {
    IROperand dest;
    IROperand src;
    IRBinaryDataOp op;

    this(IROperand dest, IROperand src, IRBinaryDataOp op) {
        this.dest = dest;
        this.src = src;
        this.op = op;
    }
}

final class IrInstructionSetFlag_Impl : IRInstruction_Impl {
    IRFlag flag;
    IROperand src;

    this(IRFlag flag, IROperand src) {
        this.flag = flag;
        this.src = src;
    }
}

final class IrInstructionDeleteVariable_Impl : IRInstruction_Impl {
    IROperand dest;

    this(IROperand dest) {
        this.dest = dest;
    }
}

alias IrInstruction = scoped!IRInstruction_Impl;
alias IrInstructionGetReg = scoped!IrInstructionGetReg_Impl;
alias IrInstructionSetReg = scoped!IrInstructionSetReg_Impl;
alias IrInstructionEvalCond = scoped!IrInstructionEvalCond_Impl;
alias IrInstructionBinaryDataOp = scoped!IrInstructionBinaryDataOp_Impl;
alias IrInstructionSetFlag = scoped!IrInstructionSetFlag_Impl;
alias IrInstructionDeleteVariable = scoped!IrInstructionDeleteVariable_Impl;