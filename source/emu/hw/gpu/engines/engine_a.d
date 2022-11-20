module emu.hw.gpu.engines.engine_a;

import emu.hw;
import util;

__gshared GPUEngineA gpu_engine_a;
final class GPUEngineA {

    PPU!(EngineType.A) ppu;

    this(MemStrategy mem) {
        ppu = new PPU!(EngineType.A)(mem);
        videobuffer = new Pixel[192][256];
    }

    int display_mode;
    int vram_block_index;
    int bg0_selection;
    int bitmap_obj_dimension;
    int bitmap_obj_mapping;
    int bitmap_obj_boundary;
    int obj_during_hblank;
    bool bg_extended_palettes;
    bool forced_blank;
    bool bg0_enable;

    void vblank() {
        gpu3d.draw_scanlines_to_canvas();
        ppu.canvas.composite();
        ppu.vblank();

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
                bg0_selection                  = value[3];
                ppu.obj_character_vram_mapping = value[4];
                bitmap_obj_dimension           = value[5];
                bitmap_obj_mapping             = value[6];
                forced_blank                   = value[7];
                break;

            case 1: 
                bg0_enable                              = value[0];
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
                vram_block_index      = value[2..3];
                ppu.tile_obj_boundary = value[4..5];
                bitmap_obj_boundary   = value[6];
                obj_during_hblank     = value[7];
                break;

            case 3: 
                ppu.character_base        = value[0..2];
                ppu.screen_base           = value[3..5];
                ppu.bg_extended_palettes  = value[6];
                ppu.obj_extended_palettes = value[7];
                break; 
        }

        ppu.backgrounds[0].enabled = bg0_enable & ~bg0_selection;
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
                result[3]    = bg0_selection;
                result[4]    = ppu.obj_character_vram_mapping;
                result[5]    = bitmap_obj_dimension;
                result[6]    = bitmap_obj_mapping;
                result[7]    = forced_blank;
                break;

            case 1: 
                result[0] = bg0_enable;
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
                result[2..3] = Byte(vram_block_index);
                result[4..5] = ppu.tile_obj_boundary;
                result[6]    = bitmap_obj_boundary;
                result[7]    = obj_during_hblank;
                break;

            case 3:
                result[0..2] = ppu.character_base;
                result[3..5] = ppu.screen_base;
                result[6]    = ppu.bg_extended_palettes;
                result[7]    = ppu.obj_extended_palettes;
                break;
        }

        return result;  
    }

    void hblank(int scanline) {
        if (bg0_selection && bg0_enable) {
            // gpu3d rendering starts 48 scanlines in advance
            if (scanline >= 214) {
                gpu3d.render(scanline - 214);
            } else if (scanline < 143) {
                gpu3d.render(scanline + 48);
            }
        }
    }
}