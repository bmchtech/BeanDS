module emu.hw.gpu.ppu.ppu;

import emu;
import util;

import std.stdio;
import std.typecons;
import std.algorithm;

enum AffineParameter {
    A = 0,
    B = 1,
    C = 2,
    D = 3
}

final class PPU(HwType H) {
    static assert (H == HwType.NDS9 || H == HwType.NDS7);

    enum Pixel RESET_PIXEL = Pixel(Half(0));

    ushort scanline;

    Canvas canvas;

    Pixel[256] scanline_buffer;

    Scheduler scheduler;

    @property 
    Byte[] bg_vram() {
        static if (H == HwType.NDS9) return vram.vram_a.data;
        static if (H == HwType.NDS7) return vram.vram_c.data;
        assert(0);
    }

    @property 
    Byte[] obj_vram() {
        static if (H == HwType.NDS9) return vram.vram_b.data;
        static if (H == HwType.NDS7) return vram.vram_d.data;
        assert(0);
    }

    this() {
        scanline = 0;

        static if (H == HwType.NDS9) canvas = new Canvas(0);
        static if (H == HwType.NDS7) canvas = new Canvas(0x400);
    }

    void render(int scanline) {
        this.scanline = cast(ushort) scanline;

        canvas.reset();

        // horizontal mosaic is a post processing effect done on the canvas
        // whereas vertical mosaic is a pre processing effect done on the
        // lcd itself.
        apply_vertical_mosaic();

        calculate_scanline();

        canvas.apply_horizontal_mosaic(bg_mosaic_h, obj_mosaic_h);

        if (bg_mode < 3) canvas.composite(scanline);

        for (int x = 0; x < 256; x++) {
            scanline_buffer[x] = canvas.pixels_output[x];
        }

        backgrounds[2].internal_reference_x += backgrounds[2].p[AffineParameter.B];
        backgrounds[2].internal_reference_y += backgrounds[2].p[AffineParameter.D];
        backgrounds[3].internal_reference_x += backgrounds[3].p[AffineParameter.B];
        backgrounds[3].internal_reference_y += backgrounds[3].p[AffineParameter.D];
    }

    void vblank() {
        reload_background_internal_affine_registers(2);
        reload_background_internal_affine_registers(3);
    }

    void calculate_scanline() {
        switch (bg_mode) {
            case 0: 
            case 1:
            case 2:
                render_sprites(0);
                render_background(0);
                render_sprites(1);
                render_background(1);
                render_sprites(2);
                render_background(2);
                render_sprites(3);
                render_background(3);
                break;
                
            default: error_ppu("tried to set ppu to invalid mode %x", bg_mode);
        }
    }

    static immutable int[][] BG_TEXT_SCREENS_DIMENSIONS = [
        [1, 1],
        [2, 1],
        [1, 2],
        [2, 2]
    ];

    static immutable int[] BG_ROTATION_SCALING_TILE_DIMENSIONS = [
        16, 32, 64, 128
    ];

    static immutable int[] BG_ROTATION_SCALING_TILE_DIMENSIONS_MASKS = [
        0xF, 0x1F, 0x3F, 0x7F      
    ];

    // a texture is a width x height set of tiles
    struct Texture {
        int base_tile_number;   // the tile number of the topleft tile
        int width;              // the amount of tiles this texture has in its width
        int height;             // the amount of tiles this texture has in its height
        int increment_per_row;  // how much to add to the tile_number per row.
    
        bool scaled;
        PMatrix p_matrix;
        Point reference_point;

        int tile_base_address;
        int palette_base_address;
        int palette;

        bool flipped_x;
        bool flipped_y;
        bool double_sized;
    }

    ushort apparent_bg_scanline;
    ushort apparent_obj_scanline;
    void apply_vertical_mosaic() {
        apparent_bg_scanline  = cast(ushort) (scanline - (scanline % bg_mosaic_v));
        apparent_obj_scanline = cast(ushort) (scanline - (scanline % obj_mosaic_v));
    }

    struct Point {
        int x;
        int y;
    }        

    pragma(inline, true) int get_tile_address__text(int tile_x, int tile_y, int screens_per_row, int screens_per_col) {
        // each screen is 32 x 32 tiles. so to get the tile offset within its screen
        // we can get the low 5 bits
        int tile_x_within_screen = tile_x & 0x1F;
        int tile_y_within_screen = tile_y & 0x1F;

        // similarly we can find out which screen this tile is located in
        // by getting its high bit
        int screen_x             = min((tile_x >> 5) & 1, screens_per_row - 1);
        int screen_y             = min((tile_y >> 5) & 1, screens_per_col - 1);
        int screen               = screen_x + screen_y * screens_per_row;

        int tile_address_offset_within_screen = ((tile_y_within_screen * 32) + tile_x_within_screen) * 2;
        return tile_address_offset_within_screen + screen * 0x800; 
    }

    pragma(inline, true) int get_tile_address__rotation_scaling(int tile_x, int tile_y, int tiles_per_row) {
        return ((tile_y * tiles_per_row) + tile_x);
    }

    template Render(bool bpp8, bool flipped_x, bool flipped_y) {

        pragma(inline, true) void tile(int bg, int priority, int tile, int tile_base_address, int palette_base_address, int left_x, int y, int palette) {
            // Point reference_point = Point(ref_x, ref_y);
            static if (bpp8) {
                static if (flipped_y) uint tile_address = tile_base_address + (tile & 0x3ff) * 64 + (7 - y) * 8;    
                else                  uint tile_address = tile_base_address + (tile & 0x3ff) * 64 + (y)     * 8;
            } else {
                static if (flipped_y) uint tile_address = tile_base_address + (tile & 0x3ff) * 32 + (7 - y) * 4;    
                else                  uint tile_address = tile_base_address + (tile & 0x3ff) * 32 + (y)     * 4;
            }
            
            Byte[8] tile_data = bg_vram[tile_address .. tile_address + 8];

            // hi. i hate this. but ive profiled it and it makes the code miles faster.
            static if (flipped_x) {
                int draw_dx = 0;

                static if (bpp8) {
                    for (int tile_dx = 7; tile_dx >= 0; tile_dx--) {
                        ubyte index = tile_data[tile_dx];
                        canvas.draw_bg_pixel(left_x + draw_dx, bg, index, priority, index == 0);
                        draw_dx++;
                    }
                } else {
                    for (int tile_dx = 3; tile_dx >= 0; tile_dx--) {
                        ubyte index = tile_data[tile_dx];
                        canvas.draw_bg_pixel(left_x + draw_dx * 2 + 1, bg, cast(ubyte) ((index & 0xF) + (palette * 16)), priority, (index & 0xF) == 0);
                        canvas.draw_bg_pixel(left_x + draw_dx * 2,     bg, cast(ubyte) ((index >> 4)  + (palette * 16)), priority, (index >> 4)  == 0);
                        draw_dx++;
                    }
                }
            } else {
                static if (bpp8) {
                    for (int tile_dx = 0; tile_dx < 8; tile_dx++) {
                        ubyte index = tile_data[tile_dx];
                        canvas.draw_bg_pixel(left_x + tile_dx, bg, index, priority, index == 0);
                    }
                } else {
                    for (int tile_dx = 0; tile_dx < 4; tile_dx++) {
                        ubyte index = tile_data[tile_dx];
                        canvas.draw_bg_pixel(left_x + tile_dx * 2,     bg, cast(ubyte) ((index & 0xF) + (palette * 16)), priority, (index & 0xF) == 0);
                        canvas.draw_bg_pixel(left_x + tile_dx * 2 + 1, bg, cast(ubyte) ((index >> 4)  + (palette * 16)), priority, (index >> 4)  == 0);
                    }
                }
            } 
        }

        pragma(inline, true) void texture(int priority, Texture texture, Point topleft_texture_pos, Point topleft_draw_pos, OBJMode obj_mode) {
            int texture_bound_x_upper = texture.double_sized ? texture.width  >> 1 : texture.width;
            int texture_bound_y_upper = texture.double_sized ? texture.height >> 1 : texture.height;
            int texture_bound_x_lower = 0;
            int texture_bound_y_lower = 0;
            
            if (obj_character_vram_mapping && bpp8) texture.base_tile_number >>= 1;

            if (texture.double_sized) {
                topleft_texture_pos.x += texture.width  >> 2;
                topleft_texture_pos.y += texture.height >> 2;
            }
            for (int draw_x_offset = 0; draw_x_offset < texture.width; draw_x_offset++) {
                Point draw_pos = Point(topleft_draw_pos.x + draw_x_offset, topleft_draw_pos.y);
                Point texture_pos = draw_pos;

                if (texture.scaled) {
                    texture_pos = multiply_P_matrix(texture.reference_point, draw_pos, texture.p_matrix);
                    if ((texture_pos.x - topleft_texture_pos.x) < texture_bound_x_lower || (texture_pos.x - topleft_texture_pos.x) >= texture_bound_x_upper ||
                        (texture_pos.y - topleft_texture_pos.y) < texture_bound_y_lower || (texture_pos.y - topleft_texture_pos.y) >= texture_bound_y_upper)
                        continue;
                }

                if (texture.flipped_x) texture_pos.x = (topleft_texture_pos.x + texture.width  - 1) - (texture_pos.x - topleft_texture_pos.x);
                if (texture.flipped_y) texture_pos.y = (topleft_texture_pos.y + texture.height - 1) - (texture_pos.y - topleft_texture_pos.y);

                int tile_x = ((texture_pos.x - topleft_texture_pos.x) >> 3);
                int tile_y = ((texture_pos.y - topleft_texture_pos.y) >> 3);
                int ofs_x  = ((texture_pos.x - topleft_texture_pos.x) & 0b111);
                int ofs_y  = ((texture_pos.y - topleft_texture_pos.y) & 0b111);

                int tile_number;
                if (!obj_character_vram_mapping) {
                    if (bpp8) tile_number = (2 * tile_x + texture.increment_per_row * tile_y + texture.base_tile_number) >> 1;
                    else tile_number = tile_x + texture.increment_per_row * tile_y + texture.base_tile_number;

                } else {
                    tile_number = tile_x + texture.increment_per_row * tile_y + texture.base_tile_number;
                }
                    

                static if (bpp8) {
                    ubyte index = obj_vram.read!Byte(Word(texture.tile_base_address + ((tile_number & 0x3ff) * 64) + ofs_y * 8 + ofs_x));
                    
                    if (obj_mode != OBJMode.OBJ_WINDOW) {
                        canvas.draw_obj_pixel(draw_pos.x, index + 256, priority, index == 0, obj_mode == OBJMode.SEMI_TRANSPARENT);
                    } else {
                        if (index != 0) canvas.set_obj_window(draw_pos.x);
                    }

                } else {
                    ubyte index = obj_vram.read!Byte(Word(texture.tile_base_address + ((tile_number & 0x3ff) * 32) + ofs_y * 4 + (ofs_x / 2)));

                    index = !(ofs_x % 2) ? index & 0xF : index >> 4;
                    index += texture.palette * 16;

                    if (obj_mode != OBJMode.OBJ_WINDOW) {
                        canvas.draw_obj_pixel(draw_pos.x, index + 256, priority, (index & 0xF) == 0, obj_mode == OBJMode.SEMI_TRANSPARENT);
                    } else {
                        if ((index & 0xF) != 0) canvas.set_obj_window(draw_pos.x);
                    }
                }
            }
        }
    }

    void render_background(uint i) {
        Background background = backgrounds[i];
        final switch (background.mode) {
            case BackgroundMode.TEXT:             render_background__text(i);             break;
            case BackgroundMode.ROTATION_SCALING: render_background__rotation_scaling(i); break;
            case BackgroundMode.NONE:             break;
        }
    }
    
    void render_background__text(uint background_id) {
        // do we even render?
        Background background = backgrounds[background_id];
        if (!background.enabled) return;

        uint bg_scanline = background.is_mosaic ? apparent_bg_scanline : scanline;

        // relevant addresses for the background's tilemap and screen
        int screen_base_address = background.screen_base_block * 0x800;
        int tile_base_address   = background.character_base_block * 0x4000;

        // the coordinates at the topleft of the background that we are drawing
        int topleft_x      = background.x_offset;
        int topleft_y      = background.y_offset + bg_scanline;

        // the tile number at the topleft of the background that we are drawing
        int topleft_tile_x = topleft_x >> 3;
        int topleft_tile_y = topleft_y >> 3;

        // how far back do we have to render the tile? because the topleft of the screen
        // usually doesn't mark the start of the tile, so these are the offsets we can
        // subtract to handle the mislignment
        int tile_dx        = topleft_x & 0b111;
        int tile_dy        = topleft_y & 0b111;

        // to understand this, go to the switch down below
        // im just precalculating this one bit since it stays the same
        int template_args  = background.doesnt_use_color_palettes << 2;

        // tile_x_offset and tile_y_offset are offsets from the topleft tile. we use this to iterate through
        // each tile.
        for (int tile_x_offset = 0; tile_x_offset < 32 + 1; tile_x_offset++) {

            // get the tile address and read it from memory
            int tile_address = get_tile_address__text(topleft_tile_x + tile_x_offset, topleft_tile_y, 
                                                      BG_TEXT_SCREENS_DIMENSIONS[background.screen_size][0],
                                                      BG_TEXT_SCREENS_DIMENSIONS[background.screen_size][1]);
            int tile = bg_vram.read!Half(Word(screen_base_address + tile_address));
            int draw_x = tile_x_offset * 8 - tile_dx;
            int draw_y = bg_scanline;
            bool flipped_x = (tile >> 10) & 1;
            bool flipped_y = (tile >> 11) & 1;

            // i hate how silly this looks, but i've checked and having the render tile function templated makes the code run a lot faster
            final switch (template_args | (flipped_x << 1) | flipped_y) {
                case 0b000: Render!(false, false, false).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b001: Render!(false, false,  true).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b010: Render!(false,  true, false).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b011: Render!(false,  true,  true).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b100: Render!( true, false, false).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b101: Render!( true, false,  true).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b110: Render!( true,  true, false).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
                case 0b111: Render!( true,  true,  true).tile(background_id, backgrounds[background_id].priority, tile.bits(0, 9), tile_base_address, 0, draw_x, tile_dy, bits(tile, 12, 15)); break;
            }
        }
    }

    void render_background__rotation_scaling(uint background_id) {
        // do we even render?
        Background background = backgrounds[background_id];
        if (!background.enabled) return;

        uint bg_scanline = background.is_mosaic ? apparent_bg_scanline : scanline;

        // relevant addresses for the background's tilemap and screen
        int screen_base_address = background.screen_base_block * 0x800;
        int tile_base_address   = background.character_base_block * 0x4000;

        // the coordinates at the topleft of the background that we are drawing
        long texture_point_x = background.internal_reference_x;
        long texture_point_y = background.internal_reference_y;

        // rotation/scaling backgrounds are squares
        int tiles_per_row = BG_ROTATION_SCALING_TILE_DIMENSIONS      [background.screen_size];
        int tile_mask     = BG_ROTATION_SCALING_TILE_DIMENSIONS_MASKS[background.screen_size];

        for (int x = 0; x < 240; x++) {
            // truncate the decimal because texture_point is 8-bit fixed point
            Point truncated_texture_point = Point(cast(int) texture_point_x >> 8,
                                                  cast(int) texture_point_y >> 8);
            int tile_x = truncated_texture_point.x >> 3;
            int tile_y = truncated_texture_point.y >> 3;
            int fine_x = truncated_texture_point.x & 0b111;
            int fine_y = truncated_texture_point.y & 0b111;

            if (background.does_display_area_overflow ||
                ((0 <= tile_x && tile_x < tiles_per_row) &&
                 (0 <= tile_y && tile_y < tiles_per_row))) {
                tile_x &= tile_mask;
                tile_y &= tile_mask;
                
                int tile_address = get_tile_address__rotation_scaling(tile_x, tile_y, tiles_per_row);
                int tile = bg_vram.read!Byte(Word(screen_base_address + tile_address));

                ubyte color_index = bg_vram.read!Byte(Word(tile_base_address + (tile & 0x3FF) * 64 + fine_y * 8 + fine_x));
                canvas.draw_bg_pixel(x, background_id, color_index, background.priority, color_index == 0);
            }

            texture_point_x += background.p[AffineParameter.A];
            texture_point_y += background.p[AffineParameter.C];
        }
    }

    // sprite_sizes[size][shape] = (width, height)
    static immutable ubyte[2][4][3] sprite_sizes = [
        [
            [8,  8],
            [16, 16],
            [32, 32],
            [64, 64]
        ],

        [
            [16, 8],
            [32, 8],
            [32, 16],
            [64, 32]
        ],

        [
            [ 8, 16],
            [ 8, 32],
            [16, 32],
            [32, 64]
        ]
    ];

    enum OBJMode {
        NORMAL           = 0,
        SEMI_TRANSPARENT = 1,
        OBJ_WINDOW       = 2,
        PROHIBITED       = 3
    }

    void render_sprites(int given_priority) {
        if (!sprites_enabled) return;

        // Very useful guide for attributes! https://problemkaputt.de/gbatek.htm#lcdobjoamattributes
        for (int sprite = 0; sprite < 128; sprite++) {

            if (oam.read!Half(Word(sprite * 8 + 4))[10..11] != given_priority) continue;

            // first of all, we need to figure out if we render this sprite in the first place.
            // so, we collect a bunch of info that'll help us figure that out.
            ushort attribute_0 = oam.read!Half(Word(sprite * 8 + 0));

            // is this sprite even enabled
            if (bits(attribute_0, 8, 9) == 0b10) continue;

            // it is enabled? great. let's get the other two attributes and collect some
            // relevant information.
            int attribute_1 = oam.read!Half(Word(sprite * 8 + 2));
            int attribute_2 = oam.read!Half(Word(sprite * 8 + 4));

            int size   = attribute_1.bits(14, 15);
            int shape  = attribute_0.bits(14, 15);

            ubyte width  = sprite_sizes[shape][size][0] >> 3;
            ubyte height = sprite_sizes[shape][size][1] >> 3;

            if (attribute_0.bit(9)) width  *= 2;
            if (attribute_0.bit(9)) height *= 2;

            int topleft_x = sext_32(Word(cast(ushort) attribute_1.bits(0, 8)), 9);
            int topleft_y = attribute_0.bits(0, 7);
            if (topleft_y > 160) topleft_y -= 256; 

            int middle_x = topleft_x + width  * 4;
            int middle_y = topleft_y + height * 4;

            bool is_mosaic = attribute_0.bit(12);

            ushort obj_scanline = is_mosaic ? apparent_obj_scanline : scanline;

            if (obj_scanline < topleft_y || obj_scanline >= topleft_y + (height << 3)) continue;

            OBJMode obj_mode = cast(OBJMode) attribute_0.bits(10, 11);

            uint base_tile_number = cast(ushort) attribute_2.bits(0, 9);
            int tile_number_increment_per_row = obj_character_vram_mapping ? (attribute_0.bit(9) ? width >> 1 : width) : 32;

            bool doesnt_use_color_palettes = attribute_0.bit(13);
            bool scaled    = attribute_0.bit(8);
            bool flipped_x = !scaled && attribute_1.bit(12);
            bool flipped_y = !scaled && attribute_1.bit(13);

            int scaling_number = attribute_1.bits(9, 13);
            // if (!obj_character_vram_mapping && doesnt_use_color_palettes) base_tile_number >>= 1;

            PMatrix p_matrix = PMatrix(
                convert_from_8_8f_to_double(oam.read!Half(Word(0x06 + 0x20 * scaling_number))),
                convert_from_8_8f_to_double(oam.read!Half(Word(0x0E + 0x20 * scaling_number))),
                convert_from_8_8f_to_double(oam.read!Half(Word(0x16 + 0x20 * scaling_number))),
                convert_from_8_8f_to_double(oam.read!Half(Word(0x1E + 0x20 * scaling_number)))
            );

            // for (int tile_x_offset = 0; tile_x_offset < width; tile_x_offset++) {

            //     // get the tile address and read it from memory
            //     // int tile_address = get_tile_address(topleft_tile_x + tile_x_offset, topleft_tile_y + tile_y_offset, tile_number_increment_per_row);
            //     int tile = base_tile_number + (((scanline - topleft_y) >> 3) * tile_number_increment_per_row) + tile_x_offset;

            //     int draw_x = flipped_x ? (width  - tile_x_offset - 1) * 8 + topleft_x : tile_x_offset * 8 + topleft_x;
            //     int draw_y = flipped_y ? (height * 8 - (scanline - topleft_y) - 1) + topleft_y: scanline;
         
            Texture texture = Texture(base_tile_number, width << 3, height << 3, tile_number_increment_per_row, 
                                        scaled, p_matrix, Point(middle_x, middle_y),
                                        0x10000, 0x200,
                                        attribute_2.bits(12, 16),
                                        flipped_x, flipped_y, attribute_0.bit(9));

            if (doesnt_use_color_palettes) Render!(true,  false, false).texture(given_priority, texture, Point(topleft_x, topleft_y), Point(topleft_x, obj_scanline), obj_mode);
            else                           Render!(false, false, false).texture(given_priority, texture, Point(topleft_x, topleft_y), Point(topleft_x, obj_scanline), obj_mode);
        }
    }

    struct PMatrix {
        double pA;
        double pB;
        double pC;
        double pD;
    }

    Point multiply_P_matrix(Point reference_point, Point original_point, PMatrix p_matrix) {
        return Point(
            cast(int) (p_matrix.pA * (original_point.x - reference_point.x) + p_matrix.pB * (original_point.y - reference_point.y)) + reference_point.x,
            cast(int) (p_matrix.pC * (original_point.x - reference_point.x) + p_matrix.pD * (original_point.y - reference_point.y)) + reference_point.y
        );
    }

    void update_bg_mode() {
        switch (bg_mode) {
            case 0:
                backgrounds[0].mode = BackgroundMode.TEXT;
                backgrounds[1].mode = BackgroundMode.TEXT;
                backgrounds[2].mode = BackgroundMode.TEXT;
                backgrounds[3].mode = BackgroundMode.TEXT;
                break;

            case 1:
                backgrounds[0].mode = BackgroundMode.TEXT;
                backgrounds[1].mode = BackgroundMode.TEXT;
                backgrounds[2].mode = BackgroundMode.ROTATION_SCALING;
                backgrounds[3].mode = BackgroundMode.NONE;
                break;

            case 2:
                backgrounds[0].mode = BackgroundMode.NONE;
                backgrounds[1].mode = BackgroundMode.NONE;
                backgrounds[2].mode = BackgroundMode.ROTATION_SCALING;
                backgrounds[3].mode = BackgroundMode.ROTATION_SCALING;
                break;
        
            default:
                break;
        }
    }

    void reload_background_internal_affine_registers(uint bg_id) {
        backgrounds[bg_id].internal_reference_x = backgrounds[bg_id].x_offset_rotation;
        backgrounds[bg_id].internal_reference_y = backgrounds[bg_id].y_offset_rotation;
    }

    double convert_from_8_8f_to_double(ushort input) {
        return ((cast(short) input) >> 8) + ((cast(double) (input & 0xFF)) / 256.0);
    }

    ushort convert_from_double_to_8_8f(double input) {
        return (cast(ushort) ((cast(ushort) (input / 1)) << 8)) | ((cast(ushort) ((input % 1) * 256)) & 0xFF);
    }

private:
    // DISPCNT
    public int bg_mode;                             // 0 - 5
    int  disp_frame_select;                         // 0 - 1
    bool hblank_interval_free;                      // 1 = OAM can be accessed during h-blank
    bool is_character_vram_mapping_one_dimensional; // 2 = 2-dimensional
    bool obj_character_vram_mapping;
    bool forced_blank;
    bool sprites_enabled;

public:
    void write_DISPCNT(int target_byte, Byte data) {
        if (target_byte == 0) {
            bg_mode                    = data[0..2];
            disp_frame_select          = data[4];
            hblank_interval_free       = data[5];
            obj_character_vram_mapping = data[6];
            forced_blank               = data[7];
            update_bg_mode();
        } else { // target_byte == 1
            backgrounds[0].enabled     = data[0];
            backgrounds[1].enabled     = data[1];
            backgrounds[2].enabled     = data[2];
            backgrounds[3].enabled     = data[3];
            sprites_enabled            = data[4];
            canvas.windows[0].enabled  = data[5];
            canvas.windows[1].enabled  = data[6];
            canvas.obj_window_enable   = data[7];
        }
    }

    void write_BGxCNT(int target_byte, Byte data, int x) {
        if (target_byte == 0) {
            backgrounds[x].priority                   = data[0..1];
            backgrounds[x].character_base_block       = data[2..5];
            backgrounds[x].is_mosaic                  = data[6];
            backgrounds[x].doesnt_use_color_palettes  = data[7];
        } else { // target_byte == 1
            backgrounds[x].screen_base_block          = data[0..4];
            backgrounds[x].does_display_area_overflow = data[5];
            backgrounds[x].screen_size                = data[6..7];
        }
    }

    void write_BGxHOFS(int target_byte, Byte data, int x) {
        if (target_byte == 0) {
            backgrounds[x].x_offset = (backgrounds[x].x_offset & 0xFF00) | data;
        } else { // target_byte == 1
            backgrounds[x].x_offset = (backgrounds[x].x_offset & 0x00FF) | (data << 8);
        }
    }

    void write_BGxVOFS(int target_byte, Byte data, int x) {
        if (target_byte == 0) {
            backgrounds[x].y_offset = (backgrounds[x].y_offset & 0xFF00) | data;
        } else { // target_byte == 1
            backgrounds[x].y_offset = (backgrounds[x].y_offset & 0x00FF) | (data << 8);
        }
    }

    void write_WINxH(int target_byte, Byte data, int x) {
        if (target_byte == 0) {
            canvas.windows[x].right = data;
        } else { // target_byte == 1
            canvas.windows[x].left = data;
        }
    }

    void write_WINxV(int target_byte, Byte data, int x) {
        if (target_byte == 0) {
            canvas.windows[x].bottom = data;
        } else { // target_byte == 1
            canvas.windows[x].top = data;
        }
    }

    void write_WININ(int target_byte, Byte data) {
        // the target_byte happens to specify the window here
        canvas.windows[target_byte].bg_enable  = data[0..3];
        canvas.windows[target_byte].obj_enable = data[4];
        canvas.windows[target_byte].blended    = data[5];
    }

    void write_WINOUT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0b0:
                canvas.outside_window_bg_enable  = data[0..3];
                canvas.outside_window_obj_enable = data[4];
                canvas.outside_window_blended    = data[5];
                break;

            case 0b1:
                canvas.obj_window_bg_enable      = data[0..3];
                canvas.obj_window_obj_enable     = data[4];
                canvas.obj_window_blended        = data[5];
                break;
        }
    }

    int bg_mosaic_h  = 1;
    int bg_mosaic_v  = 1;
    int obj_mosaic_h = 1;
    int obj_mosaic_v = 1;
    void write_MOSAIC(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0b0:
                bg_mosaic_h = (data & 0xF) + 1;
                bg_mosaic_v = (data >> 4)  + 1;
                break;

            case 0b1:
                obj_mosaic_h = (data & 0xF) + 1;
                obj_mosaic_v = (data >> 4)  + 1;
                break;
        }
    }

    void write_BGxX(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0b00:
                backgrounds[x].x_offset_rotation &= 0xFFFFFF00;
                backgrounds[x].x_offset_rotation |= data;
                break;
            case 0b01:
                backgrounds[x].x_offset_rotation &= 0xFFFF00FF;
                backgrounds[x].x_offset_rotation |= data << 8;
                break;
            case 0b10:
                backgrounds[x].x_offset_rotation &= 0xFF00FFFF;
                backgrounds[x].x_offset_rotation |= data << 16;
                break;
            case 0b11:
                backgrounds[x].x_offset_rotation &= 0x00FFFFFF;
                backgrounds[x].x_offset_rotation |= data << 24;
                backgrounds[x].x_offset_rotation &= 0x0FFFFFFF;

                // sign extension. bit 27 is the sign bit.
                backgrounds[x].x_offset_rotation |= (((data >> 3) & 1) ? 0xF000_0000 : 0x0000_0000);
                break;
        }
    }

    void write_BGxY(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0b00:
                backgrounds[x].y_offset_rotation &= 0xFFFFFF00;
                backgrounds[x].y_offset_rotation |= data;
                break;
            case 0b01:
                backgrounds[x].y_offset_rotation &= 0xFFFF00FF;
                backgrounds[x].y_offset_rotation |= data << 8;
                break;
            case 0b10:
                backgrounds[x].y_offset_rotation &= 0xFF00FFFF;
                backgrounds[x].y_offset_rotation |= data << 16;
                break;
            case 0b11:
                backgrounds[x].y_offset_rotation &= 0x00FFFFFF;
                backgrounds[x].y_offset_rotation |= data << 24;
                backgrounds[x].y_offset_rotation &= 0x0FFFFFFF;

                // sign extension. bit 27 is the sign bit.
                backgrounds[x].y_offset_rotation |= (((data >> 3) & 1) ? 0xF000_0000 : 0x0000_0000);
                break;
        }

        reload_background_internal_affine_registers(x);
    }

    void write_BGxPy(int target_byte, Byte data, int x, AffineParameter y) {
        final switch (target_byte) {
            case 0b0:
                backgrounds[x].p[cast(int) y] &= 0xFF00;
                backgrounds[x].p[cast(int) y] |= data;
                break;
            case 0b1:
                backgrounds[x].p[cast(int) y] &= 0x00FF;
                backgrounds[x].p[cast(int) y] |= data << 8;
                break;
        }
    }

    void write_BLDCNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0b0:
                for (int bg = 0; bg < 4; bg++)
                    canvas.bg_target_pixel[Layer.A][bg] = data[bg];
                canvas.obj_target_pixel[Layer.A] = data[4];
                canvas.backdrop_target_pixel[Layer.A] = data[5];

                canvas.blending_type = cast(Blending) data[6..7];

                break;
            case 0b1:
                for (int bg = 0; bg < 4; bg++)
                    canvas.bg_target_pixel[Layer.B][bg] = data[bg];
                canvas.obj_target_pixel[Layer.B] = data[4];
                canvas.backdrop_target_pixel[Layer.B] = data[5];

                break;
        }
    }

    // raw blend values will be set directly during writes to BLDALPHA. these differ
    // from the canvas blend value because the canvas blend values cap at 16 while
    // the raw blend values cap at 31. we need to store the raw values so we can
    // return them on reads from BLDALPHA
    uint raw_blend_a;
    uint raw_blend_b;
    void write_BLDALPHA(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0b0:
                raw_blend_a = data[0..4];
                canvas.blend_a = min(raw_blend_a, 16);
                break;
            case 0b1:
                raw_blend_b = data[0..4];
                canvas.blend_b = min(raw_blend_b, 16);
                break;
        }
    }

    void write_BLDY(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0b0:
                canvas.evy_coeff = data[0..4];
                if (canvas.evy_coeff > 16) canvas.evy_coeff = 16;
                break;
            case 0b1:
                break;
        }
    }

    Byte read_DISPCNT(int target_byte) {
        if (target_byte == 0) {
            return cast(Byte) ((bg_mode                    << 0) |
                               (disp_frame_select          << 4) |
                               (hblank_interval_free       << 5) |
                               (obj_character_vram_mapping << 6) |
                               (forced_blank               << 7));
        } else { // target_byte == 1
            return cast(Byte) (backgrounds[0].enabled << 0) |
                              (backgrounds[1].enabled << 1) |
                              (backgrounds[2].enabled << 2) |
                              (backgrounds[3].enabled << 3) |
                              (sprites_enabled        << 4);
        }
    }

    Byte read_VCOUNT(int target_byte) {
        if (target_byte == 0) {
            return Byte((scanline & 0x00FF) >> 0);
        } else {
            return Byte((scanline & 0xFF00) >> 8);
        }
    }

    Byte read_BGxCNT(int target_byte, int x) {
        if (target_byte == 0) {
            ubyte result = 0x00;
            result |= backgrounds[x].priority                  << 0;
            result |= backgrounds[x].character_base_block      << 2;
            result |= backgrounds[x].bgcnt_bits_4_and_5        << 4;
            result |= backgrounds[x].is_mosaic                 << 6;
            result |= backgrounds[x].doesnt_use_color_palettes << 7;
            return Byte(result);

        } else { // target_byte == 1
            // i think this method of handling register reads is cleaner than the cast(ubyte)
            // one-line method. but i dont want to change all mmio registers. maybe a task
            // for the future?
            ubyte result = 0x00;
            result |= backgrounds[x].screen_base_block          << 0;
            result |= backgrounds[x].screen_size                << 6;

            // this bit is only used in bg 2/3
            if (x == 2 || x == 3) result |= backgrounds[x].does_display_area_overflow << 5;
            return Byte(result);
        }
    }

    Byte read_BLDCNT(int target_byte) {
        final switch (target_byte) {
            case 0b0:
                ubyte return_value;
                for (int bg = 0; bg < 4; bg++)
                    return_value |= (canvas.bg_target_pixel[Layer.A][bg] << bg);
                return_value |= canvas.obj_target_pixel[Layer.A] << 4;
                return_value |= (canvas.backdrop_target_pixel[Layer.A] << 5);
                return_value |= (cast(ubyte) canvas.blending_type) << 6;

                return Byte(return_value);

            case 0b1:
                ubyte return_value;
                for (int bg = 0; bg < 4; bg++)
                    return_value |= (canvas.bg_target_pixel[Layer.B][bg] << bg);
                return_value |= (canvas.obj_target_pixel[Layer.B] << 4);
                return_value |= (canvas.backdrop_target_pixel[Layer.B] << 5);

                return Byte(return_value);
        }
    }

    Byte read_BLDALPHA(int target_byte) {
        final switch (target_byte) {
            case 0b0:
                return cast(Byte) raw_blend_a;
            case 0b1:
                return cast(Byte) raw_blend_b;
        }
    }

    Byte read_WININ(int target_byte) {
        // target_byte here is conveniently the window index
        return cast(Byte) ((canvas.windows[target_byte].bg_enable) |
                           (canvas.windows[target_byte].obj_enable << 4) |
                           (canvas.windows[target_byte].blended    << 5));
    }

    Byte read_WINOUT(int target_byte) {
        final switch (target_byte) {
            case 0b0:
                return cast(Byte) ((canvas.outside_window_bg_enable) |
                                   (canvas.outside_window_obj_enable << 4) |
                                   (canvas.outside_window_blended    << 5));
            case 0b1:
                return cast(Byte) ((canvas.obj_window_bg_enable) |
                                   (canvas.obj_window_obj_enable << 4) |
                                   (canvas.obj_window_blended    << 5));
        }
    }
}