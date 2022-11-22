module emu.hw.memory.strategy.slowmem.vram;

import emu.hw.gpu.engines;
import emu.hw.gpu.slottype;
import emu.hw.gpu.vramblock;
import emu.hw.memory.mem;
import util;

final class SlowMemVRAM {
    alias Slot = Byte[1 << 17];

    Slot*[5] slots_bg_pal_a;
    Slot*[5] slots_bg_pal_b;
    Slot*[5] slots_obj_pal_a;
    Slot*[5] slots_obj_pal_b;
    Slot*[5] slots_texture_pal;
    Slot*[5] slots_texture;

    Slot*[5][6] all_slots;

    this() {
        all_slots = [
            slots_bg_pal_a,
            slots_bg_pal_b,
            slots_obj_pal_a,
            slots_obj_pal_b,
            slots_texture_pal,
            slots_texture
        ];
    }

    VRAMBlock[10] blocks;
    bool vram_c_in_ram;
    bool vram_d_in_ram;

    void remap_slots(VRAMBlock[10] blocks) {
        this.blocks = blocks;

        for (int i = 0; i < 10; i++) {
            int num_times_mapped = 0;
            VRAMBlock block = blocks[i];
            if (block.slot_mapped) {
                for (int j = 0; j < 5; j++) {
                    if (block.slot.bit(j)) {
                        all_slots[block.slot_type][j] = cast(Slot*) (&block.data[block.slot_ofs + num_times_mapped * (SLOT_SIZE_BG)]);
                        num_times_mapped++;
                    }
                }
            }
        }
    }

    T read_slot(T)(SlotType slot_type, int slot, Word address) {
        if (((all_slots[slot_type])[slot]) == null) {
            log_vram("tried to read from slot type %s at slot %d, though no slot was mapped :(", slot_type, slot);
            return T(0);
        }

        return (*all_slots[slot_type][slot]).read!T(address);
    }

    T read_ppu(T)(Word address) {
        T result = 0;
        bool performed_read = false;

        for (int i = 0; i < 10; i++) {
            if (i == 2 && vram_c_in_ram) continue;
            if (i == 3 && vram_d_in_ram) continue;

            VRAMBlock block = blocks[i];

            if (block.slot_mapped) continue;
            

            if (block.in_range(address)) {
                result |= block.read!T(address);
                performed_read = true;
            }
        }

        return result;
    }

    T read_data9(T)(Word address) {
        static if (!is_memory_unit!T) {
            error_vram("Tried to write to VRAM with wrong type (size: %d)", T.sizeof);
            return T();
        } else {
            T result = 0;
            bool performed_read = false;

            for (int i = 0; i < 10; i++) {
                if (i == 2 && vram_c_in_ram) continue;
                if (i == 3 && vram_d_in_ram) continue;

                VRAMBlock block = blocks[i];

                if (block.slot_mapped) continue;

                if (block.in_range(address)) {
                    result |= block.read!T(address);
                    performed_read = true;
                }
            }

            if (!performed_read) log_vram("Read from VRAM from an unmapped region: %x", address);
            return result;
        }
    }

    void write_data9(T)(Word address, T value) {
        static if (!is_memory_unit!T) {
            static if (is(T == Byte)) {
                log_vram("ARM9 tried to perform a byte write of %02x to VRAM at address %08x! Ignoring.", value, address);
            }
        } else {
            bool performed_write = false;

            for (int i = 0; i < 10; i++) {
                if (i == 2 && vram_c_in_ram) continue;
                if (i == 3 && vram_d_in_ram) continue;
                
                VRAMBlock block = blocks[i];

                if (block.slot_mapped) continue;

                if (block.in_range(address)) {
                    block.write!T(address, value);
                    performed_write = true;
                }
            }

            if (!performed_write) log_vram("Wrote %x to VRAM in an unmapped region: %x", value, address);
        }
    }

    T read_data7(T)(Word address) {
        static if (!is_memory_unit!T) {
            error_vram("Tried to write to VRAM with wrong type (size: %d)", T.sizeof);
            return T();
        } else {
            T result = 0;

            if (vram_c_in_ram && blocks[2].in_range(address)) result |= blocks[2].read!T(address);
            if (vram_d_in_ram && blocks[3].in_range(address)) result |= blocks[3].read!T(address);
            if (!vram_c_in_ram && !vram_d_in_ram) {
                error_vram("Tried to read from VRAM C/D when they're not mapped to RAM!");
            }
            
            return result;
        }
    }

    void write_data7(T)(Word address, T value) {
        static if (!is_memory_unit!T) {
            error_vram("Tried to write to VRAM with wrong type (size: %d)", T.sizeof);
        } else {
            if (vram_c_in_ram && blocks[2].in_range(address)) blocks[2].write!T(address, value);
            if (vram_d_in_ram && blocks[3].in_range(address)) blocks[3].write!T(address, value);
            if (!vram_c_in_ram && !vram_d_in_ram) {
                error_vram("Tried to read from VRAM C/D when they're not mapped to RAM!");
            }
        }
    }
}