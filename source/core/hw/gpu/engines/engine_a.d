module core.hw.gpu.engines.engine_a;

import core.hw;

import util;

__gshared GPUEngineA gpu_engine_a;
final class GPUEngineA {

    this() {
        videobuffer = new Pixel[192][256];
        gpu_engine_a = this;
    }

    int bg_mode;
    int display_mode;
    int vram_block;
    void write_DISPCNT(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                bg_mode = value[0..2];
                break;

            case 1: break;

            case 2:
                display_mode = value[0..1];
                vram_block   = value[2..3];
                break;

            case 3: break; 
        }    
    }

    Pixel[192][256] videobuffer;

    void render(int scanline) {
        // just do the bitmap mode for now ig
        switch (display_mode) {
            case 2:
                Byte* vram_block = get_vram_block();
                for (int x = 0; x < 256; x++) {
                    //TODO: i hate keeping on casting to word. but i also like its benefits. i need to improve upon this type
                    videobuffer[x][scanline] = Pixel(vram_block.read!Half(cast(Word) (x + scanline * 256) * 2));
                }
                break;
            default: break;
        }
    }

    Byte* get_vram_block() {
        final switch (vram_block) {
            case 0: return vram.vram_a;
            case 1: return vram.vram_b;
            case 2: return vram.vram_c;
            case 3: return vram.vram_d;
        }
    }

    Byte read_DISPCNT(int target_byte) {
        return Byte(0);
    }
}