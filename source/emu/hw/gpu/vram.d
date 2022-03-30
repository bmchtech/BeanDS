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

    final class VRAMBlock {
        Word offset;
        size_t size;
        Byte[] data;

        this(size_t size) {
            data = new Byte[size];
            this.size = size;
            this.offset = offset;
        }

        bool in_range(Word address) {
            return offset <= address && address < offset + size;
        }

        T read(T)(Word address) {
            return data.read!T(address - offset);
        }

        void write(T)(Word address, T value) {
            data.write!T(address - offset, value);
        }
    }

    VRAMBlock[9] blocks;

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
        vram_h = blocks[7];
        vram_i = blocks[8];

        vram = this;
    }

    T read9(T)(Word address) {
        auto region = get_region(address);
        log_vram("recieved a read: %x", address);

        T result = 0;
        bool performed_read = false;

        for (int i = 0; i < 9; i++) {
            if (i == 2 && vram_c_in_ram) continue;
            if (i == 3 && vram_d_in_ram) continue;

            VRAMBlock block = blocks[i];

            if (block.in_range(address)) {
                result |= block.read!T(address);
                performed_read = true;
            }
        }

        if (!performed_read) error_vram("Read from VRAM from an unmapped region: %x", address);
        return result;
    }

    void write9(T)(Word address, T value) {
        auto region = get_region(address);
        log_vram("recieved a write: %x %x", address, value);

        bool performed_write = false;

        for (int i = 0; i < 9; i++) {
            if (i == 2 && vram_c_in_ram) continue;
            if (i == 3 && vram_d_in_ram) continue;
            
            VRAMBlock block = blocks[i];

            if (block.in_range(address)) {
                block.write!T(address, value);
                performed_write = true;
            }
        }

        if (!performed_write) error_vram("Wrote %x to VRAM in an unmapped region: %x", value, address);
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

    void write_VRAMCNT(int target_byte, Byte data) {
        log_vram("wrote to cunt: %x %x", target_byte, data);
        auto mst    = vram_bank_uses_bit_2(target_byte) ? data[0..2] : data[0..1];
        auto offset = data[3..4];

        // TODO: figure out what VRAM enable encodes

        switch (target_byte) {
            case 0: set_vram_A(mst, offset); break;
            case 1: set_vram_B(mst, offset); break;
            case 2: set_vram_C(mst, offset); break;
            case 3: set_vram_D(mst, offset); break;
            case 4: set_vram_E(     offset); break;
            case 5: set_vram_F(mst, offset); break;
            case 6: set_vram_G(mst, offset); break;
            // case 7: assert(0);
            case 8: set_vram_H(     offset); break;
            case 9: set_vram_I(     offset); break;
            default: break;
        }
    }

    bool vram_bank_uses_bit_2(int vram_bank) {
        return vram_bank == 0 ||
               vram_bank == 1 ||
               vram_bank == 8 ||
               vram_bank == 9;
    }

    void set_vram_A(int mst, int offset) {
        final switch (mst) {
            case 0: vram_a.offset = 0x0680_0000; break;
            case 1: vram_a.offset = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_a.offset = 0x0600_0000 + offset.bit(0) * 0x20000; break;
            case 3: error_unimplemented("i do not know what a slot is (%x)"); break;
        }
    }

    void set_vram_B(int mst, int offset) {
        final switch (mst) {
            case 0: vram_b.offset = 0x0682_0000; break;
            case 1: vram_b.offset = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_b.offset = 0x0600_0000 + offset.bit(0) * 0x20000; break;
            case 3: error_unimplemented("i do not know what a slot is (%x)"); break;
        }
    }

    void set_vram_C(int mst, int offset) {
        vram_c_in_ram = mst == 2;
        final switch (mst) {
            case 0: vram_c.offset = 0x0684_0000; break;
            case 1: vram_c.offset = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_c.offset = 0x0600_0000 + offset.bit(0) * 0x20000; break;
            case 3: log_unimplemented("i do not know what a slot is"); break;
            case 4: vram_c.offset = 0x0620_0000; break;
        }
    }

    void set_vram_D(int mst, int offset) {
        vram_d_in_ram = mst == 2;
        final switch (mst) {
            case 0: vram_d.offset = 0x0686_0000; break;
            case 1: vram_d.offset = 0x0600_0000 + offset * 0x20000; break;
            case 2: vram_d.offset = 0x0600_0000 + offset.bit(0) * 0x20000; break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: vram_d.offset = 0x0660_0000; break;
        }
    }

    void set_vram_E(int mst) {
        final switch (mst) {
            case 0: vram_e.offset = 0x0688_0000; break;
            case 1: vram_e.offset = 0x0600_0000; break;
            case 2: vram_e.offset = 0x0640_0000; break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_F(int mst, int offset) {
        final switch (mst) {
            case 0: vram_f.offset = 0x0689_0000; break;
            case 1: vram_f.offset = 0x0600_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 2: vram_f.offset = 0x0640_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: error_unimplemented("i do not know what a slot is"); break;
            case 5: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_G(int mst, int offset) {
        final switch (mst) {
            case 0: vram_g.offset = 0x0689_4000; break;
            case 1: vram_g.offset = 0x0600_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 2: vram_g.offset = 0x0640_0000 + 0x4000 * offset.bit(0) + 0x10000 * offset.bit(1); break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: error_unimplemented("i do not know what a slot is"); break;
            case 5: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_H(int mst) {
        final switch (mst) {
            case 0: vram_h.offset = 0x0689_8000; break;
            case 1: vram_h.offset = 0x0620_0000; break;
            case 2: error_unimplemented("i do not know what a slot is");
        }
    }

    void set_vram_I(int mst) {
        final switch (mst) {
            case 0: vram_i.offset = 0x068A_8000; break;
            case 1: vram_i.offset = 0x0620_8000;  break;
            case 2: vram_i.offset = 0x0660_0000; break;
            case 3: error_unimplemented("i do not know what a slot is");
        }
    }

    Byte read_VRAMSTAT(int target_byte) {
        Byte result = 0;
        result[0] = Byte(vram_c_in_ram);
        result[1] = Byte(vram_d_in_ram);
        return result;
    }
}