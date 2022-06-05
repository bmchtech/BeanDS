module emu.hw.gpu.gpu3d.texture;

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

float[4] get_color_from_texture(int s, int t, AnnotatedPolygon p, Word palette_base_address) {
    auto texture_s_size = (8 << p.orig.texture_s_size);
    auto texture_t_size = (8 << p.orig.texture_t_size);

    auto wrapped_s = s % texture_s_size;
    auto wrapped_t = t % texture_t_size;

    if ((s != wrapped_s && !p.orig.texture_repeat_s_direction) ||
        (t != wrapped_t && !p.orig.texture_repeat_t_direction)) {
        // we are outside of the texture region, return a transparent object
        return [0.0f, 0.0f, 0.0f, 0.0f];
    }
    
    // if ((wrapped_s & 16) ^ (wrapped_t & 16)) {
    //     return [31, 0, 0, 31];
    // } else {
    //     return [31, 31, 31, 31];
    // }

    int texel_index = cast(int) (wrapped_t * texture_s_size + wrapped_s);

    // TODO: make this a final switch when i've actually implemented all the texture formats
    switch (p.orig.texture_format) {
        case TextureFormat.COLOR_PALETTE_256:
            Byte texel = vram.read_texture!Byte(Word((p.orig.texture_vram_offset << 3) + texel_index));
            Half color = vram.read_texture!Half(palette_base_address * 16 + texel * 2);
            
            return [
                color[0..4],
                color[5..9],
                color[10..14],
                (texel == 0 && p.orig.texture_color_0_transparent) ? 0.0 : 31.0
            ];

        case TextureFormat.DIRECT_TEXTURE:
            Half texel = vram.read_texture!Half(Word((p.orig.texture_vram_offset << 3) + 2 * texel_index));

            return [
                texel[0..4],
                texel[5..9],
                texel[10..14],
                texel[15]
            ];
        
        default:
            log_gpu3d("Tried to decode an unimplemented texture: %x", cast(int) p.orig.texture_format);
    }
    
    // TODO: this return never trigger once the above switch case is made into a final switch
    return [0.0f, 0.0f, 0.0f, 0.0f];
}