module emu.hw.memory.main_memory;

import emu;
import util;

__gshared MainMemory main_memory;

final class MainMemory {
    enum MAIN_MEMORY_SIZE = 1 << 22;
    Byte[MAIN_MEMORY_SIZE] data;

    T read(T)(Word address) {
        return data.read!T(address & (MAIN_MEMORY_SIZE - 1));
    }

    void write(T)(Word address, T value) {
        if ((address & (MAIN_MEMORY_SIZE - 1)) == (0x021D3490 & (MAIN_MEMORY_SIZE - 1))) {
            // log_main_memory("OSi_CurrentThreadPtr = %x", value);
        }

        if ((address & (MAIN_MEMORY_SIZE - 1)) == (0x21d349c & (MAIN_MEMORY_SIZE - 1))) {
            // Word current_thread_addr = value;
            // Word id = mem9.read!Word(current_thread_addr + emu.debugger.hle.types.OSThread.id.offsetof);
            // log_main_memory("*OSi_CurrentThreadPtr->id = %x (offset: %x)", id, emu.debugger.hle.types.OSThread.id.offsetof);
        }

        data.write!T(address & (MAIN_MEMORY_SIZE - 1), value);
    }
}