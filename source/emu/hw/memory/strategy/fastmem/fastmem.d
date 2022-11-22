module emu.hw.memory.strategy.fastmem.fastmem;

import emu.hw.cpu.instructionblock;
import emu.hw.gpu.slottype;
import emu.hw.gpu.vramblock;
import emu.hw.memory.mmio;
import emu.hw.memory.strategy.common;
import emu.hw.memory.strategy.fastmem.virtualmemory;
import emu.hw.memory.strategy.memstrategy;
import emu.scheduler;
import std.format;
import util;

final class FastMem : MemStrategy {
    VirtualMemoryManager vmem;

    VirtualMemorySpace* mem7;
    VirtualMemorySpace* mem9;

    VirtualMemorySpace*[6] vram_slots;

    MemoryRegion* bios7;
    MemoryRegion* bios9;
    MemoryRegion* main_memory;
    MemoryRegion* wram_shared_bank_1;
    MemoryRegion* wram_shared_bank_2;
    MemoryRegion* wram_arm7;

    MemoryRegion* vram_a;
    MemoryRegion* vram_b;
    MemoryRegion* vram_c;
    MemoryRegion* vram_d;
    MemoryRegion* vram_e;
    MemoryRegion* vram_f;
    MemoryRegion* vram_g;
    MemoryRegion* vram_h;
    MemoryRegion* vram_i;

    MemoryRegion* pram;
    MemoryRegion* oam;

    MemoryRegion*[10] vram_regions;

    Word vram_c_address;
    Word vram_d_address;

    this() {
        vmem = new VirtualMemoryManager();

        this.mem7 = vmem.create_memory_space("mem7", 0x1_0000_0000);
        this.mem9 = vmem.create_memory_space("mem9", 0x1_0000_0000);

        for (int i = 0; i < 6; i++) {
            vram_slots[i] = vmem.create_memory_space("vram_slot_%d".format(i), (1 << 17) * 5);
        }

        this.bios7              = vmem.create_memory_region("bios7",         BIOS7_SIZE);
        this.bios9              = vmem.create_memory_region("bios9",         BIOS9_SIZE);
        this.main_memory        = vmem.create_memory_region("main_memory",   MAIN_MEMORY_SIZE);
        this.wram_shared_bank_1 = vmem.create_memory_region("wram_shared_1", WRAM_SIZE);
        this.wram_shared_bank_2 = vmem.create_memory_region("wram_shared_2", WRAM_SIZE);
        this.wram_arm7          = vmem.create_memory_region("wram_arm7",     ARM7_ONLY_WRAM_SIZE);
        this.vram_a             = vmem.create_memory_region("vram_a",        VRAM_A_SIZE);
        this.vram_b             = vmem.create_memory_region("vram_b",        VRAM_B_SIZE);
        this.vram_c             = vmem.create_memory_region("vram_c",        VRAM_C_SIZE);
        this.vram_d             = vmem.create_memory_region("vram_d",        VRAM_D_SIZE);
        this.vram_e             = vmem.create_memory_region("vram_e",        VRAM_E_SIZE);
        this.vram_f             = vmem.create_memory_region("vram_f",        VRAM_F_SIZE);
        this.vram_g             = vmem.create_memory_region("vram_g",        VRAM_G_SIZE);
        this.vram_h             = vmem.create_memory_region("vram_h",        VRAM_H_SIZE);
        this.vram_i             = vmem.create_memory_region("vram_i",        VRAM_I_SIZE);
        this.pram               = vmem.create_memory_region("pram",          PRAM_SIZE * 2); // PRAM_SIZE is smaller than a page. eh, we'll live.
        this.oam                = vmem.create_memory_region("oam",           OAM_SIZE  * 2); // same goes here

        // these regions of memory are unchangeable, might as well map them now.
        vmem.map(mem7, bios7, 0x0000_0000);
        vmem.map(mem9, bios9, 0xFFFF_0000);
        vmem.map_with_length(mem7, main_memory, 0x0200_0000, 0x0100_0000);
        vmem.map_with_length(mem9, main_memory, 0x0200_0000, 0x0100_0000);
        vmem.map_with_length(mem7, wram_arm7,   0x0380_0000, 0x0080_0000);
        vmem.map_with_length(mem9, pram,        0x0500_0000, 0x0100_0000);
        vmem.map_with_length(mem9, oam,         0x0700_0000, 0x0100_0000);

        vram_regions[0] = vram_a;
        vram_regions[1] = vram_b;
        vram_regions[2] = vram_c;
        vram_regions[3] = vram_d;
        vram_regions[4] = vram_e;
        vram_regions[5] = vram_f;
        vram_regions[6] = vram_g;
        // vram_regions[7] = null;
        vram_regions[8] = vram_h;
        vram_regions[9] = vram_i;
    }

    T read7(T)(Word address) {
        scheduler.tick(1);
        if (address >> 24 == 4) return mmio7.read!T(address);
        else return vmem.read!T(mem7, address);
    }

    void write7(T)(Word address, T value) {
        scheduler.tick(1);
        if (address >> 24 == 4) mmio7.write!T(address, value);
        else vmem.write!T(mem7, address, value);
    }
    
    T read9(T)(Word address) {
        scheduler.tick(1);
        if (address >> 24 == 4) return mmio9.read!T(address);
        else return vmem.read!T(mem9, address);
    }

    void write9(T)(Word address, T value) {
        scheduler.tick(1);
        if (address >> 24 == 4) mmio9.write!T(address, value);
        else vmem.write!T(mem9, address, value);
    }

    T read9_notick(T)(Word address) {
        if (address >> 24 == 4) return mmio9.read!T(address);
        else return vmem.read!T(mem9, address);
    }

    T vram_read_slot(T)(SlotType slot_type, int slot, Word address) {
        return vmem.read!T(vram_slots[slot_type], address + (slot << 17));
    }

    override {
        void vram_remap_slots(VRAMBlock[10] blocks) {
            for (int i = 0; i < 10; i++) {
                if (i == 7) continue;
                vmem.map_with_length(mem9, vram_regions[i], blocks[i].address, cast(u32) blocks[i].size);
            }

            // used when the vram is mapped to ram for the arm7
            vram_c_address = blocks[2].address;
            vram_d_address = blocks[3].address;

            for (int i = 0; i < 10; i++) {
                if (i == 7) continue;

                int num_times_mapped = 0;
                VRAMBlock block = blocks[i];
                if (block.slot_mapped) {
                    for (int j = 0; j < 5; j++) {
                        if (block.slot.bit(j)) {
                            u32 offset = block.slot_ofs + num_times_mapped * SLOT_SIZE_BG;
                            u32 address = (j << 17);
                            vmem.map_with_offset(vram_slots[block.slot_type], vram_regions[i], address, offset);
                            num_times_mapped++;
                        }
                    }
                }
            }
        }

        void wram_set_mode(int new_mode) {
            log_nds("set wram: %x", new_mode);

            final switch (new_mode) {
                case 0:
                    vmem.map_with_stride(mem9, wram_shared_bank_1, 0x0300_0000,             0x0080_0000, WRAM_SIZE * 2);
                    vmem.map_with_stride(mem9, wram_shared_bank_2, 0x0300_0000 + WRAM_SIZE, 0x0080_0000, WRAM_SIZE * 2);
                    break;
                
                case 1:
                    vmem.map_with_length(mem7, wram_shared_bank_1, 0x0300_0000, 0x0080_0000);
                    vmem.map_with_length(mem9, wram_shared_bank_2, 0x0300_0000, 0x0080_0000);
                    break;
                
                case 2:
                    vmem.map_with_length(mem7, wram_shared_bank_2, 0x0300_0000, 0x0080_0000);
                    vmem.map_with_length(mem9, wram_shared_bank_1, 0x0380_0000, 0x0080_0000);
                    break;
                
                case 3:
                    vmem.map_with_stride(mem7, wram_shared_bank_1, 0x0300_0000,             0x0080_0000, WRAM_SIZE * 2);
                    vmem.map_with_stride(mem7, wram_shared_bank_2, 0x0300_0000 + WRAM_SIZE, 0x0080_0000, WRAM_SIZE * 2);
                    break;
            }
        }

        void load_bios7(Byte[] bios) {
            for (int i = 0; i < BIOS7_SIZE; i++) {
                write7!Byte(Word(i), bios[i]);
            }
        }

        void load_bios9(Byte[] bios) {
            for (int i = 0; i < BIOS9_SIZE; i++) {
                write9!Byte(Word(0xFFFF_0000 + i), bios[i]);
            }
        }

        Word vram_read_slot_word(SlotType slot_type, int slot, Word address) { return vram_read_slot!Word(slot_type, slot, address); }
        Half vram_read_slot_half(SlotType slot_type, int slot, Word address) { return vram_read_slot!Half(slot_type, slot, address); }
        Byte vram_read_slot_byte(SlotType slot_type, int slot, Word address) { return vram_read_slot!Byte(slot_type, slot, address); }

        void vram_set_c_block_mapping(bool is_in_ram) {
            log_vram("set c block mapping: %x %x", is_in_ram, vram_c_address);
            if (is_in_ram) {
                vmem.map(mem7, vram_c, vram_c_address);
            } else {
                vmem.unmap(mem7, vram_c_address, VRAM_C_SIZE);
            }
        }

        void vram_set_d_block_mapping(bool is_in_ram) {
            log_vram("set d block mapping: %x %x", is_in_ram, vram_d_address);
            if (is_in_ram) {
                vmem.map(mem7, vram_d, vram_d_address);
            } else {
                vmem.unmap(mem7, vram_d_address, VRAM_D_SIZE);
            }
        }

        Word read_data_word7(Word address) { return read7!Word(address); }
        Half read_data_half7(Word address) { return read7!Half(address); }
        Byte read_data_byte7(Word address) { return read7!Byte(address); }
        void write_data_word7(Word address, Word value) { write7!Word(address, value); }
        void write_data_half7(Word address, Half value) { write7!Half(address, value); }
        void write_data_byte7(Word address, Byte value) { write7!Byte(address, value); }

        Word read_data_word9(Word address) { return read9!Word(address); }
        Half read_data_half9(Word address) { return read9!Half(address); }
        Byte read_data_byte9(Word address) { return read9!Byte(address); }
        void write_data_word9(Word address, Word value) { write9!Word(address, value); }
        void write_data_half9(Word address, Half value) { write9!Half(address, value); }
        void write_data_byte9(Word address, Byte value) { write9!Byte(address, value); }

        InstructionBlock* read_instruction7(Word address) { 
            scheduler.tick(1);
            return cast(InstructionBlock*) vmem.to_host_address(mem7, address);
        }
        InstructionBlock* read_instruction9(Word address) { 
            scheduler.tick(1);
            return cast(InstructionBlock*) vmem.to_host_address(mem9, address); 
        }

        Word vram_read_word(Word address) { return read9_notick!Word(address); }
        Half vram_read_half(Word address) { return read9_notick!Half(address); }
        Byte vram_read_byte(Word address) { return read9_notick!Byte(address); }

        Word pram_read_word(Word address) { return read9_notick!Word(Word(0x0500_0000) + address); }
        Half pram_read_half(Word address) { return read9_notick!Half(Word(0x0500_0000) + address); }
        Byte pram_read_byte(Word address) { return read9_notick!Byte(Word(0x0500_0000) + address); }

        Word oam_read_word(Word address) { return read9_notick!Word(Word(0x0700_0000) + address); }
        Half oam_read_half(Word address) { return read9_notick!Half(Word(0x0700_0000) + address); }
        Byte oam_read_byte(Word address) { return read9_notick!Byte(Word(0x0700_0000) + address); }
    }
}
