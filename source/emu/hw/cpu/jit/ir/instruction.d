module emu.hw.cpu.jit.ir.instruction;

import std.sumtype;

import emu.hw.cpu.jit;

alias IRInstruction(H, G) = SumType!(
    IRInstructionGetReg!(H, G),
    IRInstructionSetReg!(H, G),
    IRInstructionBinaryDataOpImm!(H, G),
    IRInstructionBinaryDataOpVar!(H, G),
    IRInstructionDeleteVariable!(H, G),
    IRInstructionUnaryDataOp!(H, G),
);

alias IRInstructionGetReg(H, G)          = IRInstructionTemplate!(H, G).IRInstructionGetReg;
alias IRInstructionSetReg(H, G)          = IRInstructionTemplate!(H, G).IRInstructionSetReg;
alias IRInstructionBinaryDataOpImm(H, G) = IRInstructionTemplate!(H, G).IRInstructionBinaryDataOpImm;
alias IRInstructionBinaryDataOpVar(H, G) = IRInstructionTemplate!(H, G).IRInstructionBinaryDataOpVar;
alias IRInstructionUnaryDataOp(H, G)     = IRInstructionTemplate!(H, G).IRInstructionUnaryDataOp;
alias IRInstructionDeleteVariable(H, G)  = IRInstructionTemplate!(H, G).IRInstructionDeleteVariable;

template IRInstructionTemplate(HostReg, GuestReg) {
    alias _IRGuestReg     = IRGuestReg!(HostReg, GuestReg);
    alias _IRVariable     = IRVariable!(HostReg, GuestReg);

    struct IRInstructionGetReg {
        _IRVariable dest;
        GuestReg src;
    }

    struct IRInstructionSetReg{
        GuestReg dest;
        _IRVariable src;
    }
    
    struct IRInstructionBinaryDataOpImm {
        IRBinaryDataOp op;
        _IRVariable dest;
        uint src;
    }
    
    struct IRInstructionBinaryDataOpVar {
        IRBinaryDataOp op;
        _IRVariable dest;
        _IRVariable src;
    }

    struct IRInstructionDeleteVariable {
        _IRVariable variable;
    }

    struct IRInstructionUnaryDataOp {
        IRUnaryDataOp op;
        _IRVariable dest;
    }
}