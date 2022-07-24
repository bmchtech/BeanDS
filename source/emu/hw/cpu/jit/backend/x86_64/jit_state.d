module emu.hw.cpu.jit.backend.x86_64.jit_state;

import util;

struct JITState {
    Word[16] regs;
    Word cpsr;
    Word spsr;
}