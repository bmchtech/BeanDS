module core.hw.memory.shared_memory;

import util;

enum SHARED_WRAM_SIZE = 1 << 15;
Byte[SHARED_WRAM_SIZE] shared_wram;