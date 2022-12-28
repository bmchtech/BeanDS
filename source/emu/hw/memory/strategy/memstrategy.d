module emu.hw.memory.strategy.memstrategy;

import emu.hw.cpu.instructionblock;
import emu.hw.gpu.slottype;
import emu.hw.gpu.vramblock;
import emu.hw.memory.strategy.fastmem;
import emu.hw.memory.strategy.slowmem;
import util;

alias Mem = SlowMem;

interface MemStrategy {
    Word read_data_word7(Word address);
    Half read_data_half7(Word address);
    Byte read_data_byte7(Word address);
    void write_data_word7(Word address, Word data);
    void write_data_half7(Word address, Half data);
    void write_data_byte7(Word address, Byte data);

    Word read_data_word9(Word address);
    Half read_data_half9(Word address);
    Byte read_data_byte9(Word address);
    void write_data_word9(Word address, Word data);
    void write_data_half9(Word address, Half data);
    void write_data_byte9(Word address, Byte data);

    InstructionBlock* read_instruction7(Word address);
    InstructionBlock* read_instruction9(Word address);

    void load_bios7(Byte[] bios);
    void load_bios9(Byte[] bios);

    void wram_set_mode(int new_mode);

    Word vram_read_slot_word(SlotType slot_type, int slot, Word address);
    Half vram_read_slot_half(SlotType slot_type, int slot, Word address);
    Byte vram_read_slot_byte(SlotType slot_type, int slot, Word address);

    Word vram_read_word(Word address);
    Half vram_read_half(Word address);
    Byte vram_read_byte(Word address);
    
    void vram_set_c_block_mapping(bool is_in_ram);
    void vram_set_d_block_mapping(bool is_in_ram);
    void vram_remap_slots(VRAMBlock[10] blocks);

    Word pram_read_word(Word address);
    Half pram_read_half(Word address);
    Byte pram_read_byte(Word address);

    Word oam_read_word(Word address);
    Half oam_read_half(Word address);
    Byte oam_read_byte(Word address);
}