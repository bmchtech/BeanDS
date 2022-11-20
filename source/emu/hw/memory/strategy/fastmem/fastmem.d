module emu.hw.memory.strategy.fastmem.fastmem;

// final class FastMem {
//     VirtualMemoryManager vmem7;

//     MemoryRegion bios7;
//     MemoryRegion main_memory;
//     MemoryRegion wram_shared_bank_1;
//     MemoryRegion wram_shared_bank_2;
//     MemoryRegion wram_arm7;
//     MemoryRegion vram_c;
//     MemoryRegion vram_d;

//     this() {
//         vmem7 = new VirtualMemoryManager();

//         this.bios7              = VirtualMemoryManager.create_memory_region("bios7",         Mem7.BIOS_SIZE);
//         this.main_memory        = VirtualMemoryManager.create_memory_region("main_memory",   MainMemory.MAIN_MEMORY_SIZE);
//         this.wram_shared_bank_1 = VirtualMemoryManager.create_memory_region("wram_shared_1", WRAM.WRAM_SIZE);
//         this.wram_shared_bank_2 = VirtualMemoryManager.create_memory_region("wram_shared_2", WRAM.WRAM_SIZE);
//         this.wram_arm7          = VirtualMemoryManager.create_memory_region("wram_arm7",     WRAM.ARM7_ONLY_WRAM_SIZE);
//         this.vram_c             = VirtualMemoryManager.create_memory_region("vram_c",        VRAM.VRAM_C_SIZE);
//         this.vram_d             = VirtualMemoryManager.create_memory_region("vram_d",        VRAM.VRAM_D_SIZE);

//         // these regions of memory are unchangeable, might as well map them now.
//         vmem7.map(bios7,              0x0000_0000);
//         vmem7.map(main_memory_region, 0x0200_0000, 0x0100_0000);
//     }

//     void map_wram() {
        
//     }
// }
