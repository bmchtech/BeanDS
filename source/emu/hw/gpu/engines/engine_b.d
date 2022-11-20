module emu.hw.gpu.engines.engine_b;

import emu.hw;
import util;

__gshared GPUEngineB gpu_engine_b;
final class GPUEngineB {
    PPU!(EngineType.B) ppu;

    this(MemStrategy mem) {
        ppu = new PPU!(EngineType.B)(mem);
        videobuffer = new Pixel[192][256];
    }

    int display_mode;
    int vram_block_index;
    int tile_obj_mapping;
    int bitmap_obj_dimension;
    int bitmap_obj_mapping;
    int tile_obj_boundary;
    int bitmap_obj_boundary;
    int obj_during_hblank;
    bool forced_blank;

    void vblank() {
        ppu.canvas.composite();

        ppu.vblank();
        gpu3d.vblank();

        for (int y = 0; y < 192; y++) {
        for (int x = 0; x < 256; x++) {
            videobuffer[x][y] = ppu.canvas.pixels_output[x][y];
        }
        }
    }

    void write_DISPCNT(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                ppu.bg_mode                    = value[0..2];
                ppu.obj_character_vram_mapping = value[4];
                bitmap_obj_dimension           = value[5];
                bitmap_obj_mapping             = value[6];
                forced_blank                   = value[7];
                break;

            case 1: 
                ppu.backgrounds[0].enabled              = value[0];
                ppu.backgrounds[1].enabled              = value[1];
                ppu.backgrounds[2].enabled              = value[2];
                ppu.backgrounds[3].enabled              = value[3];
                ppu.sprites_enabled                     = value[4];
                ppu.canvas.mmio_info.windows[0].enabled = value[5];
                ppu.canvas.mmio_info.windows[1].enabled = value[6];
                ppu.canvas.mmio_info.obj_window_enable  = value[7];
                break;

            case 2:
                display_mode          = value[0..1];
                ppu.tile_obj_boundary = value[4..5];
                obj_during_hblank     = value[7];
                break;

            case 3: 
                ppu.character_base        = value[0..2];
                ppu.screen_base           = value[3..5];
                ppu.bg_extended_palettes  = value[6];
                ppu.obj_extended_palettes = value[7];
                break; 
        }
        
        ppu.update_bg_mode();
    }

    Pixel[192][256] videobuffer;

    void render(int scanline) {
        // just do the bitmap mode for now ig
        switch (display_mode) {
            case 0:
                for (int x = 0; x < 256; x++) videobuffer[x][scanline] = Pixel(Half(0xFFFF));
                break;

            case 1:
                ppu.render(scanline);
                break;

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
        final switch (vram_block_index) {
            case 0: return cast(Byte*) vram.vram_a.data;
            case 1: return cast(Byte*) vram.vram_b.data;
            case 2: return cast(Byte*) vram.vram_c.data;
            case 3: return cast(Byte*) vram.vram_d.data;
        }
    }

    Byte read_DISPCNT(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0..2] = ppu.bg_mode;
                result[4]    = ppu.obj_character_vram_mapping;
                result[5]    = bitmap_obj_dimension;
                result[6]    = bitmap_obj_mapping;
                result[7]    = forced_blank;
                break;

            case 1: 
                result[0] = ppu.backgrounds[0].enabled;
                result[1] = ppu.backgrounds[1].enabled;
                result[2] = ppu.backgrounds[2].enabled;
                result[3] = ppu.backgrounds[3].enabled;
                result[4] = ppu.sprites_enabled;
                result[5] = ppu.canvas.mmio_info.windows[0].enabled;
                result[6] = ppu.canvas.mmio_info.windows[0].enabled;
                result[7] = ppu.canvas.mmio_info.obj_window_enable;
                break;

            case 2:
                result[0..1] = Byte(display_mode);
                result[4..5] = ppu.tile_obj_boundary;
                result[7]    = obj_during_hblank;
                break;

            case 3:
                result[6] = ppu.bg_extended_palettes;
                result[7] = ppu.obj_extended_palettes;
                break;
        }

        return result;  
    }

    void hblank(int scanline) {

    }
}