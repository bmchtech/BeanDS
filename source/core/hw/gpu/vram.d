module emu.hw.gpu.vram;

import emu.hw;

import util;

__gshared VRAM vram;
final class VRAM {
    enum VRAM_ENGINE_A_BG_SIZE  = 1 << 19;
    enum VRAM_ENGINE_B_BG_SIZE  = 1 << 17;
    enum VRAM_ENGINE_A_OBJ_SIZE = 1 << 18;
    enum VRAM_ENGINE_B_OBJ_SIZE = 1 << 17;
    enum LCDC_SIZE              = 671744; // wtf?

    Byte[VRAM_ENGINE_A_BG_SIZE ] vram_engine_a_bg  = new Byte[VRAM_ENGINE_A_BG_SIZE ];
    Byte[VRAM_ENGINE_B_BG_SIZE ] vram_engine_b_bg  = new Byte[VRAM_ENGINE_B_BG_SIZE ];
    Byte[VRAM_ENGINE_A_OBJ_SIZE] vram_engine_a_obj = new Byte[VRAM_ENGINE_A_OBJ_SIZE];
    Byte[VRAM_ENGINE_B_OBJ_SIZE] vram_engine_b_obj = new Byte[VRAM_ENGINE_B_OBJ_SIZE];
    Byte[LCDC_SIZE]              vram_lcdc         = new Byte[LCDC_SIZE];
    
    Byte* vram_a;
    Byte* vram_b;
    Byte* vram_c;
    Byte* vram_d;
    Byte* vram_e;
    Byte* vram_f;
    Byte* vram_g;
    Byte* vram_h;
    Byte* vram_i;

    this() {
        vram = this;
    }

    T read(T)(Word address) {
        auto region = get_region(address);
        
        switch (region) {
            case 0: .. case 1: return vram_engine_a_bg .read!T(address % VRAM_ENGINE_A_BG_SIZE );
            case 2: .. case 3: return vram_engine_b_bg .read!T(address % VRAM_ENGINE_B_BG_SIZE );
            case 4: .. case 5: return vram_engine_a_obj.read!T(address % VRAM_ENGINE_A_OBJ_SIZE);
            case 6: .. case 7: return vram_engine_b_obj.read!T(address % VRAM_ENGINE_B_OBJ_SIZE);

            default: return vram_lcdc.read!T(address[0..16] % LCDC_SIZE);
        }

        assert(0);
    }

    void write(T)(Word address, T value) {
        auto region = get_region(address);
        
        switch (region) {
            case 0: .. case 1: vram_engine_a_bg .write!T(address % VRAM_ENGINE_A_BG_SIZE , value); break;
            case 2: .. case 3: vram_engine_b_bg .write!T(address % VRAM_ENGINE_B_BG_SIZE , value); break;
            case 4: .. case 5: vram_engine_a_obj.write!T(address % VRAM_ENGINE_A_OBJ_SIZE, value); break;
            case 6: .. case 7: vram_engine_b_obj.write!T(address % VRAM_ENGINE_B_OBJ_SIZE, value); break;

            default: vram_lcdc.write!T(address[0..16] % LCDC_SIZE, value);
        }
    }

    auto get_region(Word address) {
        return address[20..23];
    }

    void write_VRAMCNT(int target_byte, Byte data) {
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
            case 0: vram_a = vram_lcdc.ptr;         break;
            case 1: vram_a = vram_engine_a_bg.ptr;  break;
            case 2: vram_a = vram_engine_a_obj.ptr; break;
            case 3: error_unimplemented("i do not know what a slot is (%x)"); break;
        }
    }

    void set_vram_B(int mst, int offset) {
        final switch (mst) {
            case 0: vram_b = vram_lcdc.ptr;         break;
            case 1: vram_b = vram_engine_a_bg.ptr;  break;
            case 2: vram_b = vram_engine_a_obj.ptr; break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_C(int mst, int offset) {
        final switch (mst) {
            case 0: vram_c = vram_lcdc.ptr;        break;
            case 1: vram_c = vram_engine_a_bg.ptr; break;
            case 2: error_unimplemented("tried to set vram C as arm7 ram"); break;
            case 3: error_unimplemented("i do not know what a slot is");    break;
            case 4: vram_c = vram_engine_b_bg.ptr; break;
        }
    }

    void set_vram_D(int mst, int offset) {
        final switch (mst) {
            case 0: vram_d = vram_lcdc.ptr;        break;
            case 1: vram_d = vram_engine_a_bg.ptr; break;
            case 2: error_unimplemented("tried to set vram C as arm7 ram"); break;
            case 3: error_unimplemented("i do not know what a slot is");    break;
            case 4: vram_d = vram_engine_b_bg.ptr; break;
        }
    }

    void set_vram_E(int mst) {
        final switch (mst) {
            case 0: vram_e = vram_lcdc.ptr;         break;
            case 1: vram_e = vram_engine_a_bg.ptr;  break;
            case 2: vram_e = vram_engine_a_obj.ptr; break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_F(int mst, int offset) {
        final switch (mst) {
            case 0: vram_f = vram_lcdc.ptr;         break;
            case 1: vram_f = vram_engine_a_bg.ptr;  break;
            case 2: vram_f = vram_engine_a_obj.ptr; break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: error_unimplemented("i do not know what a slot is"); break;
            case 5: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_G(int mst, int offset) {
        final switch (mst) {
            case 0: vram_g = vram_lcdc.ptr;         break;
            case 1: vram_g = vram_engine_a_bg.ptr;  break;
            case 2: vram_g = vram_engine_a_obj.ptr; break;
            case 3: error_unimplemented("i do not know what a slot is"); break;
            case 4: error_unimplemented("i do not know what a slot is"); break;
            case 5: error_unimplemented("i do not know what a slot is"); break;
        }
    }

    void set_vram_H(int mst) {
        final switch (mst) {
            case 0: vram_a = vram_lcdc.ptr;        break;
            case 1: vram_a = vram_engine_b_bg.ptr; break;
            case 2: error_unimplemented("i do not know what a slot is");
        }
    }

    void set_vram_I(int mst) {
        final switch (mst) {
            case 0: vram_i = vram_lcdc.ptr;         break;
            case 1: vram_i = vram_engine_b_bg.ptr;  break;
            case 2: vram_i = vram_engine_b_obj.ptr; break;
            case 3: error_unimplemented("i do not know what a slot is");
        }
    }
}