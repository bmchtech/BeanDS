module emu.hw.memory.strategy.slowmem.slowmem;

import core.stdc.string;
import emu.hw.cpu.instructionblock;
import emu.hw.gpu.slottype;
import emu.hw.gpu.vramblock;
import emu.hw.memory.mem;
import emu.hw.memory.mmio;
import emu.hw.memory.strategy.common;
import emu.hw.memory.strategy.memstrategy;
import emu.hw.memory.strategy.slowmem.oam;
import emu.hw.memory.strategy.slowmem.pram;
import emu.hw.memory.strategy.slowmem.vram;
import emu.hw.memory.strategy.slowmem.wram;
import emu.scheduler;
import util;

final class SlowMem : MemStrategy {
    // these memory regions are simple enough to just use a byte array
    Byte[BIOS7_SIZE] bios7;
    Byte[BIOS9_SIZE] bios9;
    Byte[MAIN_MEMORY_SIZE] main_memory;

    // these memory regions are more complex and each require a separate class
    SlowMemWRAM wram;
    SlowMemVRAM vram;
    SlowMemPRAM pram;
    SlowMemOAM  oam;

    this() {
        bios7 = new Byte[BIOS7_SIZE];
        bios9 = new Byte[BIOS9_SIZE];
        main_memory = new Byte[MAIN_MEMORY_SIZE];
        wram = new SlowMemWRAM();
        vram = new SlowMemVRAM();
        pram = new SlowMemPRAM();
        oam = new SlowMemOAM();
    }

    T read_data7(T)(Word address) {
        scheduler.tick(1);

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x0: .. case 0x1: return bios7.read!T(address);
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              return wram.read_data7!T(address);
            case 0x4:              return mmio7.read!T(address);
            case 0x6:              return vram.read_data7!T(address);
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM7 to read from GBA Slot ROM: %x", address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM7 to read from GBA Slot RAM: %x", address); break;
            
            default: log_unimplemented("Attempt from ARM7 to read from an invalid region of memory: %x", address); break;
        }

        // should never happen
        // assert(0);
        return T();
    }

    void write_data7(T)(Word address, T value) {
        scheduler.tick(1);

        auto region = get_region(address);

        if (address[28..31]) error_unimplemented("Attempt from ARM7 to write %x to an invalid region of memory: %x", value, address);

        switch (region) {
            case 0x0: .. case 0x1: log_mem7("Attempt from ARM7 to write %x to BIOS: %x", value, address); break;
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value); break;
            case 0x3:              wram.write_data7!T(address, value); break;
            case 0x4:              mmio7.write!T(address, value); break;
            case 0x6:              vram.write_data7!T(address, value); break;
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM7 to write %x to GBA Slot ROM: %x", value, address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM7 to write %x to GBA Slot RAM: %x", value, address); break;

            default: log_unimplemented("Attempt from ARM7 to write %x to an invalid region of memory: %x", value, address); break;
        }
    }

    T read_data9(T)(Word address) {
        scheduler.tick(1);

        auto region = get_region(address);

        if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address);

        switch (region) {
            case 0x2:              return main_memory.read!T(address % MAIN_MEMORY_SIZE);
            case 0x3:              return wram.read_data9!T(address);
            case 0x4:              return mmio9.read!T(address);
            case 0x5:              return pram.read!T(address);
            case 0x6:              return vram.read_data9!T(address);
            case 0x7:              return oam.read!T(address);
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM9 to read from GBA Slot ROM: %x", address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM9 to read from GBA Slot RAM: %x", address); break;
            case 0xF:              return bios9.read!T(address[0..15]);
        
            default: log_unimplemented("Attempt from ARM9 to read from an invalid region of memory: %x", address); break;
        }

        // should never happen
        return T();
    }

    void write_data9(T)(Word address, T value) {
        scheduler.tick(1);
        
        auto region = get_region(address);

        if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address);

        switch (region) {
            case 0x2:              main_memory.write!T(address % MAIN_MEMORY_SIZE, value); break;
            case 0x3:              wram.write_data9!T(address, value); break;
            case 0x4:              mmio9.write!T(address, value); break;
            case 0x5:              pram.write!T(address, value); break;
            case 0x6:              vram.write_data9!T(address, value); break;
            case 0x7:              oam.write!T(address, value); break;
            case 0x8: .. case 0x9: log_unimplemented("Attempt from ARM9 to write %x to GBA Slot ROM: %x", value, address); break;
            case 0xA: .. case 0xB: log_unimplemented("Attempt from ARM9 to write %x to GBA Slot RAM: %x", value, address); break;
            case 0xF:              error_mem9("Attempt to write %x to BIOS: %x", value, address); break;
        
            default: log_unimplemented("Attempt from ARM9 to write %x to an invalid region of memory: %x", value, address); break;
        }
    }

    T vram_read_slot(T)(SlotType slot_type, int slot, Word address) {
        return vram.read_slot!T(slot_type, slot, address);
    }

    T vram_read_ppu(T)(Word address) {
        return vram.read_ppu!T(address);
    }

    override {
        InstructionBlock* read_instruction7(Word address) {
            scheduler.tick(1);

            auto region = get_region(address);

            if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM7 to perform an instruction read from an invalid region of memory: %x", address);

            switch (region) {
                case 0x0: .. case 0x1: return bios7.instruction_read(address);
                case 0x2:              return main_memory.instruction_read(address % MAIN_MEMORY_SIZE);
                case 0x3:              return wram.instruction_read7(address);
                
                default: error_unimplemented("Attempt from ARM7 to perform an instruction read from an invalid region of memory: %x", address); break;
            }

            error_mem7("ARM7 instruction read from invalid address: %x", address);
            return null;
        }

        InstructionBlock* read_instruction9(Word address) {
            scheduler.tick(1);

            auto region = get_region(address);

            if (address[28..31] && region != 0xF) error_unimplemented("Attempt from ARM9 to perform an instruction read from an invalid region of memory: %x", address);

            switch (region) {
                case 0x2: return main_memory.instruction_read(address % MAIN_MEMORY_SIZE);
                case 0x3: return wram.instruction_read9(address);
                case 0xF: return bios9.instruction_read(address[0..15]);
                
                default: error_unimplemented("Attempt from ARM9 to perform an instruction read from an invalid region of memory: %x", address); break;
            }

            error_mem9("ARM9 instruction read from invalid address: %x", address);
            return null;
        }

        void load_bios7(Byte[] bios) {
            for (int i = 0; i < BIOS7_SIZE; i++) {
                bios7.write!Byte(i, bios[i]);
            }
        }

        void load_bios9(Byte[] bios) {
            for (int i = 0; i < BIOS9_SIZE; i++) {
                bios9.write!Byte(i, bios[i]);
            }
        }

        void wram_set_mode(int new_mode) {
            wram.set_mode(new_mode);
        }

        void vram_set_c_block_mapping(bool is_in_ram) {
            vram.vram_c_in_ram = is_in_ram;
        }

        void vram_set_d_block_mapping(bool is_in_ram) {
            vram.vram_d_in_ram = is_in_ram;
        }

        void vram_remap_slots(VRAMBlock[10] blocks) {
            vram.remap_slots(blocks);
        }

        Word read_data_word7(Word address) { return read_data7!Word(address); }
        Half read_data_half7(Word address) { return read_data7!Half(address); }
        Byte read_data_byte7(Word address) { return read_data7!Byte(address); }
        void write_data_word7(Word address, Word value) { write_data7!Word(address, value); }
        void write_data_half7(Word address, Half value) { write_data7!Half(address, value); }
        void write_data_byte7(Word address, Byte value) { write_data7!Byte(address, value); }

        Word read_data_word9(Word address) { return read_data9!Word(address); }
        Half read_data_half9(Word address) { return read_data9!Half(address); }
        Byte read_data_byte9(Word address) { return read_data9!Byte(address); }
        void write_data_word9(Word address, Word value) { write_data9!Word(address, value); }
        void write_data_half9(Word address, Half value) { write_data9!Half(address, value); }
        void write_data_byte9(Word address, Byte value) { write_data9!Byte(address, value); }

        Word vram_read_slot_word(SlotType slot_type, int slot, Word address) { return vram_read_slot!Word(slot_type, slot, address); }
        Half vram_read_slot_half(SlotType slot_type, int slot, Word address) { return vram_read_slot!Half(slot_type, slot, address); }
        Byte vram_read_slot_byte(SlotType slot_type, int slot, Word address) { return vram_read_slot!Byte(slot_type, slot, address); }
        
        Word vram_read_word(Word address) { return vram_read_ppu!Word(address); }
        Half vram_read_half(Word address) { return vram_read_ppu!Half(address); }
        Byte vram_read_byte(Word address) { return vram_read_ppu!Byte(address); }

        Word pram_read_word(Word address) { return pram.read!Word(address); }
        Half pram_read_half(Word address) { return pram.read!Half(address); }
        Byte pram_read_byte(Word address) { return pram.read!Byte(address); }

        void pram_write_word(Word address, Word value) { pram.write!Word(address, value); }
        void pram_write_half(Word address, Half value) { pram.write!Half(address, value); }
        void pram_write_byte(Word address, Byte value) { pram.write!Byte(address, value); }

        Word oam_read_word(Word address) { return oam.read!Word(address); }
        Half oam_read_half(Word address) { return oam.read!Half(address); }
        Byte oam_read_byte(Word address) { return oam.read!Byte(address); }

        void oam_write_word(Word address, Word value) { oam.write!Word(address, value); }
        void oam_write_half(Word address, Half value) { oam.write!Half(address, value); }
        void oam_write_byte(Word address, Byte value) { oam.write!Byte(address, value); }
    }
}