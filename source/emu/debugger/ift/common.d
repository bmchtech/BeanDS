module emu.debugger.ift.common;

import emu;
import util;

ulong hwtype_to_ulong(HwType hw_type) {
    final switch (hw_type) {
        case HwType.NDS7: return 0;
        case HwType.NDS9: return 1;
    }
}