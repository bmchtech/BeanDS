module emu.hw.gpu.gpu3d.texture;

import std.algorithm.comparison;

import emu;
import util;

enum TextureFormat {
    NONE                 = 0,
    A3I5_TRANSLUCENT     = 1,
    COLOR_PALETTE_4      = 2,
    COLOR_PALETTE_16     = 3,
    COLOR_PALETTE_256    = 4,
    TEXEL_COMPRESSED_4x4 = 5,
    A5I3_TRANSLUCENT     = 6,
    DIRECT_TEXTURE       = 7
}

T read_slot(T)(SlotType slot_type, Word address) {
    int slot = address >> 17;
    if (slot > 4) slot = 4;

    return vram.read_slot!T(slot_type, slot, address % (1 << 17));
}

float[4] get_color_from_texture(int s, int t, AnnotatedPolygon p, Word palette_base_address) {
    auto texture_s_size = (8 << p.orig.texture_s_size);
    auto texture_t_size = (8 << p.orig.texture_t_size);

    if (p.orig.texture_repeat_s_direction) {
        if (p.orig.texture_flip_s_direction) {
            if (s & texture_s_size) {
                s = (s & ~(texture_s_size - 1)) | ((texture_s_size - 1) - (s & (texture_s_size - 1)));
            }

            s &= (texture_s_size << 1) - 1;
        } else {
            s &= texture_s_size - 1;
        }
    } else {
        s = clamp(s, 0, texture_s_size - 1);
    }

    if (p.orig.texture_repeat_t_direction) {
        if (p.orig.texture_flip_t_direction) {
            if (t & texture_t_size) {
                t = (t & ~(texture_t_size - 1)) | ((texture_t_size - 1) - (t & (texture_t_size - 1)));
            }

            t &= (texture_t_size << 1) - 1;
        } else {
            t &= texture_t_size - 1;
        }
    } else {
        t = clamp(t, 0, texture_t_size - 1);
    }

    // if (p.orig.texture_repeat_s_direction) ||
    //     (t != wrapped_t && !p.orig.texture_repeat_t_direction)) {
    //     // we are outside of the texture region, return a transparent object
    //     return [0.0f, 0.0f, 0.0f, 0.0f];
    // }
    
    // if ((wrapped_s & 16) ^ (wrapped_t & 16)) {
    //     return [31, 0, 0, 31];
    // } else {
    //     return [31, 31, 31, 31];
    // }

    int texel_index = cast(int) (t * texture_s_size + s);

    final switch (p.orig.texture_format) {
        case TextureFormat.COLOR_PALETTE_4:
            Byte texel = read_slot!Byte(SlotType.TEXTURE, Word((p.orig.texture_vram_offset << 3) + texel_index / 4));
            texel >>= (2 * (texel_index % 4));
            texel &= 3;
            Half color = read_slot!Half(SlotType.TEXTURE_PAL, Word(palette_base_address) * 8 + Word(texel) * 2);
            log_gpu3d("color palette 4: texel_index: %x, texel: %x, color: %x, texture_vram_offset: %x", texel_index, texel, color, p.orig.texture_vram_offset);
            // log_gpu3d("dickless: %x", Word((p.orig.texture_vram_offset << 3) + texel_index / 4));

            return [
                color[0..4],
                color[5..9],
                color[10..14],
                (texel == 0 && p.orig.texture_color_0_transparent) ? 0.0 : 31.0
            ];
        
        case TextureFormat.COLOR_PALETTE_16:
            Byte texel = read_slot!Byte(SlotType.TEXTURE, Word((p.orig.texture_vram_offset << 3) + texel_index / 2));
            texel >>= (4 * (texel_index % 2));
            texel &= 15;
            Half color = read_slot!Half(SlotType.TEXTURE_PAL, Word(palette_base_address) * 16 + Word(texel) * 2);
            
            return [
                color[0..4],
                color[5..9],
                color[10..14],
                (texel == 0 && p.orig.texture_color_0_transparent) ? 0.0 : 31.0
            ];

        case TextureFormat.COLOR_PALETTE_256:
            int slot = (Word((p.orig.texture_vram_offset << 3) + texel_index)) >> 17;
            if (slot < 0 || slot > 5) 
                error_gpu3d("something bad happened.  GRR %x %x", p.orig.texture_vram_offset, texel_index);
            Byte texel = read_slot!Byte(SlotType.TEXTURE, Word((p.orig.texture_vram_offset << 3) + texel_index));
            Half color = read_slot!Half(SlotType.TEXTURE_PAL, Word(palette_base_address) * 16 + Word(texel) * 2);
            
            return [
                color[0..4],
                color[5..9],
                color[10..14],
                (texel == 0 && p.orig.texture_color_0_transparent) ? 0.0 : 31.0
            ];
        
        case TextureFormat.TEXEL_COMPRESSED_4x4:
            uint blocks_per_row = texture_s_size / 4;
            uint block_x = s / 4;
            uint block_y = t / 4;
            uint block_fine_x = s % 4;
            uint block_fine_y = t % 4;
            uint block_index = block_y * blocks_per_row + block_x;

            Word compressed_block_base_address = (Word(p.orig.texture_vram_offset) << 3) + block_index * 4 + block_fine_y;

            Word compressed_block = read_slot!Byte(SlotType.TEXTURE, compressed_block_base_address);
            int texel = (compressed_block >> (2 * block_fine_x)) & 3;
            // log_gpu3d("texelinfo: %x %x %x %x %x %x %x %x", compressed_block, texel, texel_idx, block_fine_index, s, t, texture_s_size, texture_t_size);

            int compressed_block_slot = compressed_block_base_address >> 17;
            if (compressed_block_slot != 0 && compressed_block_slot != 2) error_gpu3d("Invalid slot for compressed texture: (address: %x offset: %x, idx: %x)", compressed_block_base_address, p.orig.texture_vram_offset, texel_index);
            
            Word palette_info_address = (1 << 17) + compressed_block_slot * 0x8000 + compressed_block_base_address / 2;
            Half palette_info = read_slot!Half(SlotType.TEXTURE, palette_info_address);
            int palette_offset = palette_info[0 ..13];
            int palette_mode   = palette_info[14..15];

            Word color_addr = palette_base_address * 16 + palette_offset * 4;

            // From GBATek:

            // The 2bit Texel values (0..3) are intepreted depending on the Mode (0..3),
            //   Texel  Mode 0       Mode 1             Mode 2         Mode 3
            //   0      Color 0      Color0             Color 0        Color 0
            //   1      Color 1      Color1             Color 1        Color 1
            //   2      Color 2      (Color0+Color1)/2  Color 2        (Color0*5+Color1*3)/8
            //   3      Transparent  Transparent        Color 3        (Color0*3+Color1*5)/8

            Half get_color_from_idx(int idx) {
                return read_slot!Half(SlotType.TEXTURE_PAL, color_addr + Word(idx) * 2);
            }

            float[4] half_to_color(Half h) {
                return [
                    h[0..4],
                    h[5..9],
                    h[10..14],
                    31.0,
                ];
            }

            final switch (texel) {
                case 0:
                case 1:
                    return half_to_color(get_color_from_idx(texel));

                case 2:   
                    final switch (palette_mode) {
                        case 0:
                        case 2:
                            return half_to_color(get_color_from_idx(2));
                        
                        case 1:
                            Half color0 = get_color_from_idx(0);
                            Half color1 = get_color_from_idx(1);
                            return [
                                (color0[0..4]   + color1[0..4])   / 2,
                                (color0[5..9]   + color1[5..9])   / 2,
                                (color0[10..14] + color1[10..14]) / 2,
                                31.0
                            ];
                        
                        case 3:
                            Half color0 = get_color_from_idx(0);
                            Half color1 = get_color_from_idx(1);
                            return [
                                (color0[0..4]   * 5 + color1[0..4]   * 3) / 8,
                                (color0[5..9]   * 5 + color1[5..9]   * 3) / 8,
                                (color0[10..14] * 5 + color1[10..14] * 3) / 8,
                                31.0
                            ];
                    }
                
                case 3:
                    final switch (palette_mode) {
                        case 0:
                        case 1:
                            return [
                                0,
                                0,
                                0,
                                0.0f
                            ];
                        
                        case 2:
                            return half_to_color(get_color_from_idx(3));
                        
                        case 3:
                            Half color0 = get_color_from_idx(0);
                            Half color1 = get_color_from_idx(1);
                            return [
                                (color0[0..4]   * 3 + color1[0..4]   * 5) / 8,
                                (color0[5..9]   * 3 + color1[5..9]   * 5) / 8,
                                (color0[10..14] * 3 + color1[10..14] * 5) / 8,
                                31.0
                            ];
                    }
            }

        case TextureFormat.DIRECT_TEXTURE:
            Half texel = read_slot!Half(SlotType.TEXTURE, Word((p.orig.texture_vram_offset << 3) + 2 * texel_index));

            return [
                texel[0..4],
                texel[5..9],
                texel[10..14],
                texel[15]
            ];
        
        case TextureFormat.A3I5_TRANSLUCENT:
            int slot = (Word((p.orig.texture_vram_offset << 3) + texel_index)) >> 17;
            Byte texel = read_slot!Byte(SlotType.TEXTURE, Word((p.orig.texture_vram_offset << 3) + texel_index));

            int index = texel[0..4];
            int alpha = texel[5..7];
            alpha = alpha * 4 + alpha / 2;
            
            Half color = read_slot!Half(SlotType.TEXTURE_PAL, Word(palette_base_address) * 16 + Word(index) * 2);

            return [
                color[0..4],
                color[5..9],
                color[10..14],
                alpha
            ];
        
        case TextureFormat.A5I3_TRANSLUCENT:
            int slot = (Word((p.orig.texture_vram_offset << 3) + texel_index)) >> 17;
            Byte texel = read_slot!Byte(SlotType.TEXTURE, Word((p.orig.texture_vram_offset << 3) + texel_index));

            int index = texel[0..2];
            int alpha = texel[3..7];
            
            Half color = read_slot!Half(SlotType.TEXTURE_PAL, Word(palette_base_address) * 16 + Word(index) * 2);

            return [
                color[0..4],
                color[5..9],
                color[10..14],
                alpha
            ];
        
        case TextureFormat.NONE:
            error_gpu3d("this can never happen");
    }
    
    // TODO: this return never trigger once the above switch case is made into a final switch
    return [0.0f, 0.0f, 0.0f, 0.0f];
}