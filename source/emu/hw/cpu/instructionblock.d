module emu.hw.cpu.instructionblock;

import util;

enum INSTRUCTION_BLOCK_SIZE = 1 << 10; // must be a power of 2

struct InstructionBlock {
    alias code this;

    align(1):
    Byte[INSTRUCTION_BLOCK_SIZE] code;
}