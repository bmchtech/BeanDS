module emu.debugger.ift.arch;

import std.array;
import std.format;

import infoflow.analysis.ift;
import infoflow.models;

import emu;

string generate_logged_reg_enum()() {
    auto mixed_in = appender!string;

    mixed_in ~= "enum IFTReg {";
    static foreach (hw_type; [HwType.NDS7, HwType.NDS9]) {
    static foreach (cpu_mode; [MODE_USER, MODE_SUPERVISOR, MODE_ABORT, MODE_UNDEFINED, MODE_IRQ, MODE_FIQ, MODE_SYSTEM]) {
    static foreach (reg; 0..16) {
        mixed_in ~= "%s_%s_%02d = %d,".format(
            created_logged_reg_string!hw_type,
            created_logged_reg_string!cpu_mode,
            reg,
            create_logged_reg(hw_type, reg, cpu_mode)
        );
    }
    }
    }

    // TOFIX: this is incredibly scuffed
    mixed_in ~= "PC = -1";
    mixed_in ~= "};";

    return mixed_in.data;
}

mixin(generate_logged_reg_enum!());

alias NDS_IFT_MEMWORD = ulong;
alias NDS_IFT_REGWORD = ulong;

alias NDSInfoLog = InfoLog!(
    NDS_IFT_REGWORD,
    NDS_IFT_MEMWORD,
    IFTReg
);

alias NDSIFTAnalysis = IFTAnalysis!(
    NDS_IFT_REGWORD,
    NDS_IFT_MEMWORD,
    IFTReg
);

mixin(NDSInfoLog.GenAliases!("NDSInfoLog"));

// sussine