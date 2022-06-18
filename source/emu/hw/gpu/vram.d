module emu.hw.gpu.vram;

import emu.hw;

import util;

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

        bool slot_mapped;
        int  slot;

        this(size_t size) {
            data = new Byte[size];
            this.size = size;

            this.slot_mapped = false;
            this.slot = 0; // TODO: is the start behavior predictable at all? and more importantly, does it matter?
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
    }

    T read_bg_slot(EngineType E, T)(int slot, Word address) {
        final switch (E) {
            case EngineType.A:
                if (vram_e.slot_mapped) return vram_e.data.read!T(Word(SLOT_SIZE * slot + address));
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

    T read_obj_slot(EngineType E, T)(int slot, Word address) {
        final switch (E) {
            case EngineType.A:
                if (vram_f.slot_mapped) return vram_f.data.read!T(address);
                if (vram_g.slot_mapped) return vram_g.data.read!T(address);
                break;

            case EngineType.B:
                if (vram_i.slot_mapped) return vram_i.data.read!T(address);
                break;
        }

        error_vram("Tried to draw from obj slot but no slots were mapped!");
        return T(0);
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

    T read_texture(T)(Word address) {
        T result = 0;

        int slot = address[17..18];
        for (int i = 0; i < 10; i++) {
            VRAMBlock block = blocks[i];

            if (block.slot_mapped && block.slot == slot) {
                result |= block.data.read!T(address[0..16]);
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

        // if (!performed_read) log_vram("Read from VRAM from an unmapped region: %x", address);
        return result;
    }

    void write9(T)(Word address, T value) {
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

        // if (!performed_write) log_vram("Wrote %x to VRAM in an unmapped region: %x", value, address);
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
            case 3: vram_a.slot    = offset; break;
        }
    }

    void set_vram_B(int mst, int offset) {
        vram_b.mst         = mst;
        vram_b.offset      = offset;
        vram_b.slot_mapped = mst == 3;

        final switch (mst) {
            case 0: vram_b.address = 0x0682_0000; break;
            case 1: vram_b.address = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_b.address = 0x0640_0000 + offset.bit(0) * 0x20000; break;
            case 3: vram_b.slot    = offset; break;
        }
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
            case 3: vram_c.slot    = offset; break;
            case 4: vram_c.address = 0x0620_0000; break;
        }
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
            case 3: vram_d.slot    = offset; break;
            case 4: vram_d.address = 0x0660_0000; break;
        }
    }

    void set_vram_E(int mst) {
        vram_e.mst         = mst;
        vram_e.slot_mapped = mst == 4;

        final switch (mst) {
            case 0: vram_e.address = 0x0688_0000; break;
            case 1: vram_e.address = 0x0600_0000; break;
            case 2: vram_e.address = 0x0640_0000; break;
            case 3: log_unimplemented("i do not understand what to do here"); break;
            case 4: log_unimplemented("help me oh slot gods"); break;
        }
    }

    void set_vram_F(int mst, int offset) {
        vram_f.mst         = mst;
        vram_f.offset      = offset;
        vram_f.slot_mapped = mst > 2;

        final switch (mst) {
            case 0: vram_f.address = 0x0689_0000; break;
            case 1: vram_f.address = 0x0600_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 2: vram_f.address = 0x0640_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 3: vram_f.slot    = offset.bit(0) + offset.bit(1) * 4; break;
            case 4: log_unimplemented("i do not understand what to do here"); break;
            case 5: log_unimplemented("i do not understand what to do here"); break;
        }
    }

    void set_vram_G(int mst, int offset) {
        vram_g.mst         = mst;
        vram_g.offset      = offset;
        vram_g.slot_mapped = mst > 2;

        final switch (mst) {
            case 0: vram_g.address = 0x0689_4000; break;
            case 1: vram_g.address = 0x0600_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 2: vram_g.address = 0x0640_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 3: vram_g.slot    = offset.bit(0) + offset.bit(1) * 4; break;
            case 4: log_unimplemented("i do not understand what to do here"); break;
            case 5: log_unimplemented("i do not understand what to do here"); break;
        }
    }

    void set_vram_H(int mst) {
        vram_h.mst         = mst;
        vram_h.slot_mapped = mst == 2;

        final switch (mst) {
            case 0: vram_h.address = 0x0689_8000; break;
            case 1: vram_h.address = 0x0620_0000; break;
            case 2: log_unimplemented("i do not understand what to do here"); break;
        }
    }

    void set_vram_I(int mst) {
        vram_i.mst         = mst;
        vram_i.slot_mapped = mst == 3;

        final switch (mst) {
            case 0: vram_i.address = 0x068A_0000; break;
            case 1: vram_i.address = 0x0620_8000; break;
            case 2: vram_i.address = 0x0660_0000; break;
            case 3: vram_i.slot    = 0; break;
        }
    }

    Byte read_VRAMSTAT(int target_byte) {
        Byte result = 0;
        result[0] = Byte(vram_c_in_ram);
        result[1] = Byte(vram_d_in_ram);
        return result;
    }
}