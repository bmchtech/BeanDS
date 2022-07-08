module emu.debugger.ift.logged_reg;

import emu;
import util;

string created_logged_reg_string(HwType hw_type)() {
    final switch (hw_type) {
        case HwType.NDS7: return "ARM7";
        case HwType.NDS9: return "ARM9";
    }
}

string created_logged_reg_string(CpuMode cpu_mode)() {
    return cpu_mode.SHORTNAME;
}

ulong cpumode_to_ulong(CpuMode cpu_mode, Reg reg) {
    bool is_banked = !(cpu_mode.REGISTER_UNIQUENESS.bit(reg) & 1);
    if (!is_banked) cpu_mode = MODE_USER;

    if (cpu_mode == MODE_USER)       return 0;
    if (cpu_mode == MODE_SUPERVISOR) return 1;
    if (cpu_mode == MODE_ABORT)      return 2;
    if (cpu_mode == MODE_UNDEFINED)  return 3;
    if (cpu_mode == MODE_IRQ)        return 4;
    if (cpu_mode == MODE_FIQ)        return 5;
    if (cpu_mode == MODE_SYSTEM)     return 6;
    
    error_ift("This state should be unreachable (an invalid CpuMode must have been passed in)");
    return 0;
}

ulong create_logged_reg(HwType hw_type, Reg reg, CpuMode cpu_mode) {
    Word result;
    result[0]    = hwtype_to_ulong(hw_type);
    result[1..4] = reg;
    result[5..7] = cpumode_to_ulong(cpu_mode, reg);

    return cast(ulong) result;
}