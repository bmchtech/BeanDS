module emu.hw.gpu.vram;

import emu;

import util;

enum SlotType {
    BG_PAL_A = 0,
    BG_PAL_B = 1,
    OBJ_PAL_A = 2,
    OBJ_PAL_B = 3,
    TEXTURE_PAL = 4,
    TEXTURE = 5
};

__gshared VRAM vram;
final class VRAM {
    enum VRAM_A_SIZE = 1 << 17;
    enum VRAM_B_SIZE = 1 << 17;
    enum VRAM_C_SIZE = 1 << 17;
    enum VRAM_D_SIZE = 1 << 17;
    enum VRAM_E_SIZE = 1 << 16;
    enum VRAM_F_SIZE = 1 << 14;
    enum VRAM_G_SIZE = 1 << 14;
    enum VRAM_H_SIZE = 1 << 15;
    enum VRAM_I_SIZE = 1 << 14;

    enum SLOT_SIZE   = 1 << 13;

    final class VRAMBlock {
        Word address;
        size_t size;
        Byte[] data;
        
        Byte mst;
        Byte offset;
        bool enabled;

        SlotType slot_type;
        bool slot_mapped;
        int  slot; // bitfield
        int  slot_ofs = 0;

        this(size_t size) {
            data = new Byte[size];
            this.size = size;

            this.slot_mapped = false;
        }

        bool in_range(Word access_address) {
            return enabled && address <= access_address && access_address < address + size;
        }

        T read(T)(Word access_address) {
            return data.read!T(access_address - address);
        }

        void write(T)(Word access_address, T value) {
            data.write!T(access_address - address, value);
        }
    }

    VRAMBlock[10] blocks;

    VRAMBlock vram_a;
    VRAMBlock vram_b;
    VRAMBlock vram_c;
    VRAMBlock vram_d;
    VRAMBlock vram_e;
    VRAMBlock vram_f;
    VRAMBlock vram_g;
    VRAMBlock vram_h;
    VRAMBlock vram_i;

    bool vram_c_in_ram;
    bool vram_d_in_ram;

    alias Slot = Byte[SLOT_SIZE];

    Slot*[5] slots_bg_pal_a;
    Slot*[5] slots_bg_pal_b;
    Slot*[5] slots_obj_pal_a;
    Slot*[5] slots_obj_pal_b;
    Slot*[5] slots_texture_pal;
    Slot*[5] slots_texture;

    Slot*[5][6] all_slots;

    this() {
        blocks = [
            new VRAMBlock(VRAM_A_SIZE),
            new VRAMBlock(VRAM_B_SIZE),
            new VRAMBlock(VRAM_C_SIZE),
            new VRAMBlock(VRAM_D_SIZE),
            new VRAMBlock(VRAM_E_SIZE),
            new VRAMBlock(VRAM_F_SIZE),
            new VRAMBlock(VRAM_G_SIZE),
            new VRAMBlock(0),
            new VRAMBlock(VRAM_H_SIZE),
            new VRAMBlock(VRAM_I_SIZE),
        ];

        vram_a = blocks[0];
        vram_b = blocks[1];
        vram_c = blocks[2];
        vram_d = blocks[3];
        vram_e = blocks[4];
        vram_f = blocks[5];
        vram_g = blocks[6];
        vram_h = blocks[8];
        vram_i = blocks[9];

        vram = this;
        
        all_slots = [
            slots_bg_pal_a,
            slots_bg_pal_b,
            slots_obj_pal_a,
            slots_obj_pal_b,
            slots_texture_pal,
            slots_texture
        ];
    }

    void remap_slots() {
        for (int i = 0; i < 10; i++) {
            VRAMBlock block = blocks[i];
            if (block.slot_mapped) {
                for (int j = 0; j < 5; j++) {
                    if (block.slot.bit(j)) {
                        all_slots[block.slot_type][j] = cast(Slot*) (&block.data[SLOT_SIZE * (j - block.slot_ofs)]);
                        log_vram("mapped: %s %x %x %x %x", block.slot_type, j, i, SLOT_SIZE * (j - block.slot_ofs), (&block.data[SLOT_SIZE * (j - block.slot_ofs)]) - &block.data[0]);
                    }
                }
            }
        }
    }


    T read_bg_slot(EngineType E, T)(int slot, Word address) {
        final switch (E) {
            case EngineType.A:
                // if (vram_e.slot_mapped) return vram_e.data.read!T(Word(SLOT_SIZE * slot + address));
                if (vram_f.slot_mapped) {
                    if (slot <  2 && vram_f.offset == 0) return vram_f.data.read!T(Word(SLOT_SIZE * slot + address));
                    if (slot >= 2 && vram_f.offset == 1) return vram_f.data.read!T(Word(SLOT_SIZE * (slot - 2) + address));
                }
                if (vram_g.slot_mapped) {
                    if (slot <  2 && vram_g.offset == 0) return vram_g.data.read!T(Word(SLOT_SIZE * slot + address));
                    if (slot >= 2 && vram_g.offset == 1) return vram_g.data.read!T(Word(SLOT_SIZE * (slot - 2) + address));
                }
                break;
            case EngineType.B:
                return vram_h.data.read!T(Word(SLOT_SIZE * slot + address));
        }

        error_vram("Tried to draw from bg slot but no slots were mapped!");
        return T(0);
    }

    T read_slot(T)(SlotType slot_type, int slot, Word address) {
        if (((all_slots[slot_type])[slot]) == null) {
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

    T read9(T)(Word address) {
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

    void write9(T)(Word address, T value) {
        static if (is(T == Byte)) {
            log_vram("ARM9 tried to perform a byte write of %02x to VRAM at address %08x! Ignoring.", value, address);
        }

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

    T read7(T)(Word address) {
        T result = 0;

        for (int i = 2; i < 4; i++) {
            if (i == 2 && vram_c_in_ram && vram_c.in_range(address)) result |= vram_c.read!T(address);
            if (i == 2 && vram_d_in_ram && vram_d.in_range(address)) result |= vram_d.read!T(address);
        }
        
        return result;
    }

    void write7(T)(Word address, T value) {
        for (int i = 2; i < 4; i++) {
            if (i == 2 && vram_c_in_ram && vram_c.in_range(address)) vram_c.write!T(address, value);
            if (i == 2 && vram_d_in_ram && vram_d.in_range(address)) vram_d.write!T(address, value);
        }
    }

    auto get_region(Word address) {
        return address[20..23];
    }

    Byte read_VRAMCNT(int target_byte) {
        Byte result = 0;

        switch (target_byte) {
            case 0, 1, 2, 3, 5, 6:
                if (vram_bank_uses_bit_2(target_byte)) {
                    result[0..2] = blocks[target_byte].mst;
                } else {
                    result[0..1] = blocks[target_byte].mst;
                }

                break;

            default: break;
        }

        result[3..4] = blocks[target_byte].offset;
        result[7] = blocks[target_byte].enabled;
        return result;
    }

    void write_VRAMCNT(int target_byte, Byte data) {
        auto mst    = vram_bank_uses_bit_2(target_byte) ? data[0..2] : data[0..1];
        auto offset = data[3..4];
        blocks[target_byte].enabled = data[7];

        // TODO: figure out if i need to zero out the unused bits

        switch (target_byte) {
            case 0: set_vram_A(mst, offset); break;
            case 1: set_vram_B(mst, offset); break;
            case 2: set_vram_C(mst, offset); break;
            case 3: set_vram_D(mst, offset); break;
            case 4: set_vram_E(mst        ); break;
            case 5: set_vram_F(mst, offset); break;
            case 6: set_vram_G(mst, offset); break;
            // case 7: assert(0);
            case 8: set_vram_H(mst        ); break;
            case 9: set_vram_I(mst        ); break;
            default: break;
        }
    }

    bool vram_bank_uses_bit_2(int vram_bank) {
        return !(vram_bank == 0 ||
                 vram_bank == 1 ||
                 vram_bank == 8 ||
                 vram_bank == 9);
    }

    void set_vram_A(int mst, int offset) {
        vram_a.mst         = mst;
        vram_a.offset      = offset;
        vram_a.slot_mapped = mst == 3;

        final switch (mst) {
            case 0: vram_a.address = 0x0680_0000; break;
            case 1: vram_a.address = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_a.address = 0x0640_0000 + offset.bit(0) * 0x20000; break;
            case 3: vram_a.slot = 1 << offset; vram_a.slot_type = SlotType.TEXTURE; break;
        }

        remap_slots();
    }

    void set_vram_B(int mst, int offset) {
        vram_b.mst         = mst;
        vram_b.offset      = offset;
        vram_b.slot_mapped = mst == 3;

        final switch (mst) {
            case 0: vram_b.address = 0x0682_0000; break;
            case 1: vram_b.address = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_b.address = 0x0640_0000 + offset.bit(0) * 0x20000; break;
            case 3: vram_b.slot = 1 << offset; vram_b.slot_type = SlotType.TEXTURE; break;
        }

        remap_slots();
    }

    void set_vram_C(int mst, int offset) {
        vram_c.mst         = mst;
        vram_c.offset      = offset;
        vram_c.slot_mapped = mst == 3;

        vram_c_in_ram = mst == 2;
        final switch (mst) {
            case 0: vram_c.address = 0x0684_0000; break;
            case 1: vram_c.address = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_c.address = 0x0600_0000 + offset.bit(0) * 0x20000; break;
            case 3: vram_c.slot = 1 << offset; vram_c.slot_type = SlotType.TEXTURE; break;
            case 4: vram_c.address = 0x0620_0000; break;
        }

        remap_slots();
    }

    void set_vram_D(int mst, int offset) {
        vram_d.mst         = mst;
        vram_d.offset      = offset;
        vram_d.slot_mapped = mst == 3;

        vram_d_in_ram = mst == 2;
        final switch (mst) {
            case 0: vram_d.address = 0x0686_0000; break;
            case 1: vram_d.address = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_d.address = 0x0600_0000 + offset.bit(0) * 0x20000; break;
            case 3: vram_d.slot = 1 << offset; vram_d.slot_type = SlotType.TEXTURE; break;
            case 4: vram_d.address = 0x0660_0000; break;
        }

        remap_slots();
    }

    void set_vram_E(int mst) {
        vram_e.mst         = mst;
        vram_e.slot_mapped = mst > 2;

        final switch (mst) {
            case 0: vram_e.address = 0x0688_0000; break;
            case 1: vram_e.address = 0x0600_0000; break;
            case 2: vram_e.address = 0x0640_0000; break;
            case 3: vram_e.slot = 0b1111; vram_e.slot_type = SlotType.TEXTURE_PAL; break;
            case 4: vram_e.slot = 0b1111; vram_e.slot_type = SlotType.BG_PAL_A; break;
        }

        remap_slots();
    }

    void set_vram_F(int mst, int offset) {
        vram_f.mst         = mst;
        vram_f.offset      = offset;
        vram_f.slot_mapped = mst > 2;

        final switch (mst) {
            case 0: vram_f.address = 0x0689_0000; break;
            case 1: vram_f.address = 0x0600_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 2: vram_f.address = 0x0640_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 3: vram_f.slot = 1 << (offset.bit(0) + offset.bit(1) * 4); vram_f.slot_ofs = offset.bit(1) * 4; vram_f.slot_type = SlotType.TEXTURE_PAL; break;
            case 4: vram_f.slot = 0b11 << (offset.bit(0) * 2); vram_f.slot_ofs = offset.bit(0) * 2; vram_f.slot_type = SlotType.BG_PAL_A; break;
            case 5: vram_f.slot = 1; vram_f.slot_ofs = 0; vram_f.slot_type = SlotType.OBJ_PAL_A; break;
        }

        remap_slots();
    }

    void set_vram_G(int mst, int offset) {
        vram_g.mst         = mst;
        vram_g.offset      = offset;
        vram_g.slot_mapped = mst > 2;

        final switch (mst) {
            case 0: vram_g.address = 0x0689_4000; break;
            case 1: vram_g.address = 0x0600_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 2: vram_g.address = 0x0640_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 3: vram_g.slot = 1 << (offset.bit(0) + offset.bit(1) * 4); vram_f.slot_ofs = offset.bit(1) * 4; vram_g.slot_type = SlotType.TEXTURE_PAL; break;
            case 4: vram_g.slot = 0b11 << (offset.bit(0) * 2); vram_g.slot_ofs = offset.bit(0) * 2; vram_g.slot_type = SlotType.BG_PAL_A; break;
            case 5: vram_g.slot = 1; vram_g.slot_ofs = 0; vram_g.slot_type = SlotType.OBJ_PAL_A; break;
        }

        remap_slots();
    }

    void set_vram_H(int mst) {
        vram_h.mst         = mst;
        vram_h.slot_mapped = mst == 2;

        final switch (mst) {
            case 0: vram_h.address = 0x0689_8000; break;
            case 1: vram_h.address = 0x0620_0000; break;
            case 2: vram_h.slot = 0b1111; vram_h.slot_type = SlotType.BG_PAL_B; break;
        }

        remap_slots();
    }

    void set_vram_I(int mst) {
        vram_i.mst         = mst;
        vram_i.slot_mapped = mst == 3;

        final switch (mst) {
            case 0: vram_i.address = 0x068A_0000; break;
            case 1: vram_i.address = 0x0620_8000; break;
            case 2: vram_i.address = 0x0660_0000; break;
            case 3: vram_i.slot = 1; vram_i.slot_type = SlotType.OBJ_PAL_B; break;
        }

        remap_slots();
    }

    Byte read_VRAMSTAT(int target_byte) {
        Byte result = 0;
        result[0] = Byte(vram_c_in_ram);
        result[1] = Byte(vram_d_in_ram);
        return result;
    }
}