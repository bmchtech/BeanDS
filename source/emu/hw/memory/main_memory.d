module emu.hw.memory.main_memory;

import util;

enum MAIN_MEMORY_SIZE = 1 << 22;
Byte[MAIN_MEMORY_SIZE] main_memory;