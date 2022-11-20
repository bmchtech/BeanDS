module emu.hw.memory.mem9;

// import emu.hw.cpu.armcpu;
// import emu.hw.gpu.oam;
// import emu.hw.gpu.pram;
// import emu.hw.gpu.vram;
// import emu.hw.memory.main_memory;
// import emu.hw.memory.mem;
// import emu.hw.memory.mmio.mmio9;
// import emu.hw.memory.wram;
// import emu.scheduler;
// import util;

// __gshared Mem9 mem9;
// final class Mem9 : Mem {
//     enum BIOS_SIZE = 3072;
//     Byte[BIOS_SIZE] bios = new Byte[BIOS_SIZE];

//     this() {
//         mem9 = this;
//     }

//     InstructionBlock* instruction_read(Word address) {
//         scheduler.tick(1);

//         auto region = get_region(address);

//         if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to perform an instruction read from an invalid region of memory: %x", address);

//         switch (region) {
//             case 0xF: return bios.instruction_read(address[0..15]);
//             case 0x2: return main_memory.instruction_read(address);
//             case 0x3: return wram.instruction_read9(address);
            
//             default: error_unimplemented("Attempt from ARM9 to perform an instruction read from an invalid region of memory: %x", address); break;
//         }

//         error_mem9("ARM9 instruction read from invalid address: %x", address);
//         return null;
//     }

//     T read(T)(Word address) {
//         scheduler.tick(1);

//         auto region = get_region(address);

//         if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address);

//         switch (region) {
//             case 0x2:              return main_memory.read!T(address);
//             case 0x3:              return wram.read9!T(address);
//             case 0x4:              return mmio9.read!T(address);
//             case 0x5:              return pram.read!T(address);
//             case 0x6:              return vram.read9!T(address);
//             case 0x7:              return oam.read!T(address);
//             case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM9 to read from GBA Slot ROM: %x", address); break;
//             case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM9 to read from GBA Slot RAM: %x", address); break;
//             case 0xF:              return bios.read!T(address[0..15]);
        
//             default: log_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address); break;
//         }

//         // should never happen
//         return T();
//     }

//     void write(T)(Word address, T value) {
//         scheduler.tick(1);
        
//         auto region = get_region(address);

//         if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address);

//         switch (region) {
//             case 0x2:              main_memory.write!T(address, value); break;
//             case 0x3:              wram.write9!T(address, value); break;
//             case 0x4:              mmio9.write!T(address, value); break;
//             case 0x5:              pram.write!T(address, value); break;
//             case 0x6:              vram.write9!T(address, value); break;
//             case 0x7:              oam.write!T(address, value); break;
//             case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM9 to write %x to GBA Slot ROM: %x", value, address); break;
//             case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM9 to write %x to GBA Slot RAM: %x", value, address); break;
//             case 0xF:              error_mem9("Attempt to write %x to BIOS: %x", value, address); break;
        
//             default: log_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address); break;
//         }
//     }

//     void load_bios(Byte[] bios) {
//         this.bios[0..BIOS_SIZE] = bios[0..BIOS_SIZE];
//     }

//     override {
//         void write_word(Word address, Word value) { write!Word(address, value); }
//         void write_half(Word address, Half value) { write!Half(address, value); }
//         void write_byte(Word address, Byte value) { write!Byte(address, value); }
//         Word read_word(Word address) { return read!Word(address); }
//         Half read_half(Word address) { return read!Half(address); }
//         Byte read_byte(Word address) { return read!Byte(address); }
//     }
// }
