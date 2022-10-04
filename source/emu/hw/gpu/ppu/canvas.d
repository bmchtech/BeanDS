module emu.hw.gpu.ppu.canvas;

import emu;
import util;

import std.stdio;
import std.algorithm;

import core.stdc.string;
            
import inteli.smmintrin;

// okay so the rules here go like this:
// an empty pixel is invalid. renders the background pixel.
// a single pixel contains one valid pixel in indices_a. 
// a double pixel contains two valid pixels. a, and b. (blending)

// now here's where things get interesting. a pixel that has been assigned
// as single cannot change its type again until reset() is called. a pixel
// can become a single type if it started off as empty. this is because
// set_pixel() is called in decreasing priority order. so if the first pixel
// it sees is a single pixel, then that's the one it goes with. additionally,
// a pixel can become a single type if it started off as a double_a, and 
// set_pixel is then called with type single. then, the pixel type is changed
// to single without changing the value of indices_a itself. this is because
// if we see this ordering, then layer b isn't visible in that pixel, and so
// blending should not occur. 

// now for more details about blending (aka double pixels). if a pixel is empty,
// and is assigned type double_a, then it is set to double_a. if a pixel
// is double_a and a layer b pixel comes in, then we set the pixel type to
// DOUBLE_AB.

struct PaletteIndex {
    int slot;
    int index;
    bool is_obj;
    bool is_3d;
    int r;
    int g;
    int b;
    int a;

    Pixel resolve(EngineType E)(int pram_offset) {
        static if (E == EngineType.A) SlotType bg_slot_type  = SlotType.BG_PAL_A;
        static if (E == EngineType.B) SlotType bg_slot_type  = SlotType.BG_PAL_B;
        static if (E == EngineType.A) SlotType obj_slot_type = SlotType.OBJ_PAL_A;
        static if (E == EngineType.B) SlotType obj_slot_type = SlotType.OBJ_PAL_B;
        Pixel p;

        if (is_3d) {
            p.r = r;
            p.g = g;
            p.b = b;
            p.a = a;
        } else {
            if (slot == -1) p = Pixel(pram.read!Half(Word(pram_offset + index * 2)));
            else {
                if (is_obj) p = Pixel(vram.read_slot!Half(obj_slot_type, slot, Word(index * 2)));
                else        p = Pixel(vram.read_slot!Half(bg_slot_type,  slot, Word(index * 2)));
            }
        }
        
        return p;
    }
}

struct PixelData {
    bool         transparent;
    PaletteIndex index;
    uint         priority;
}

enum WindowType {
    ZERO    = 0,
    ONE     = 1,
    OBJ     = 2,
    OUTSIDE = 3,
    NONE    = 4
}

enum Layer {
    A = 0,
    B = 1
}

enum Blending {
    NONE = 0,
    ALPHA = 1,
    BRIGHTNESS_INCREASE = 2,
    BRIGHTNESS_DECREASE = 3
}

struct Window {
    int left;
    int right;
    int top;
    int bottom;

    bool enabled;
    bool blended;

    // bg_enable is 4 bits
    int  bg_enable;
    bool obj_enable;
}

final class Canvas(EngineType E) {
    
    public:
        struct MMIOInfo {
            // fields for blending
            Blending blending_type;
            uint evy_coeff;
            
            // these are the blend values given to us
            uint blend_a;
            uint blend_b;

            // accessed as bg_target_pixel[layer][bg_id]. tells you if
            // the bg is a target pixel on that layer
            bool[4][2] bg_target_pixel;

            // these are the same as bg_target_pixel, just without the need for a bg_id
            bool[2]    obj_target_pixel;
            bool[2]    backdrop_target_pixel;

            // fields for windowing
            Window[2] windows;
            int outside_window_bg_enable;
            bool outside_window_obj_enable;
            int  obj_window_bg_enable;
            bool obj_window_obj_enable;
            bool obj_window_enable;

            bool obj_window_blended;
            bool outside_window_blended;
        }

        struct ScanlineCompositingInfo {
            MMIOInfo mmio_info;

            PixelData[256][4] bg_scanline;
            PixelData[256]    obj_scanline;

            bool[256] obj_window;
            bool[256] obj_semitransparent;

            void reset() {
                for (int x = 0; x < 256; x++) {
                    for (int bg = 0; bg < 4; bg++) {
                        bg_scanline[bg][x].transparent = true;
                    }

                    obj_scanline       [x].transparent = true;
                    obj_scanline       [x].priority    = 4;
                    obj_window         [x]             = false;
                    obj_semitransparent[x]             = false;
                }
            }
        }

        MMIOInfo mmio_info;
        ScanlineCompositingInfo*     scanline_compositing_info;
        ScanlineCompositingInfo[192] scanline_compositing_infos;
        Pixel[192][256] pixels_output;


    private:
        PPU!E ppu;
        Background[4] sorted_backgrounds;
        int pram_offset;

    public this(PPU!E ppu, int pram_offset) {
        this.ppu         = ppu;
        this.pram_offset = pram_offset;
        
        reset();
    }

    public void reset() {
        for (int i = 0; i < 192; i++) {
            scanline_compositing_infos[i].reset();
        }

        scanline_compositing_info = &scanline_compositing_infos[0];
    }

    public void on_hblank_start() {
        scanline_compositing_info.mmio_info = mmio_info;
    }

    public void on_hblank_end(int scanline) {
        if (scanline >= 192) return;

        scanline_compositing_info = &scanline_compositing_infos[scanline];
        scanline_compositing_info.reset();
    }

    public pragma(inline, true) void set_obj_window(uint x) {
        if (x >= 256) return;
        scanline_compositing_info.obj_window[x] = true;
    }

    static if (E == EngineType.A) {
        public pragma(inline, true) void draw_3d_pixel(int scanline, uint x, Pixel p, bool transparent) {
            if (x >= 256) return;
            scanline_compositing_infos[scanline].bg_scanline[0][x].transparent = transparent;
            scanline_compositing_infos[scanline].bg_scanline[0][x].index       = PaletteIndex(-1, 0, false, true, p.r, p.g, p.b, p.a);
            scanline_compositing_infos[scanline].bg_scanline[0][x].priority    = gpu_engine_a.ppu.backgrounds[0].priority; // TODO: this whole canvas system needs a refactor.
        }
    }

    public pragma(inline, true) void draw_bg_pixel(uint x, int bg, int slot, int index, int priority, bool transparent) {
        if (x >= 256) return;

        scanline_compositing_info.bg_scanline[bg][x].transparent = transparent;
        scanline_compositing_info.bg_scanline[bg][x].index       = PaletteIndex(slot, index, false, false, 0, 0, 0);
        scanline_compositing_info.bg_scanline[bg][x].priority    = priority;
    }

    public pragma(inline, true) void draw_obj_pixel(uint x, int slot, int index, int priority, bool transparent, bool semi_transparent) {
        if (x >= 256) return;
        
        // obj rendeWindowTypering on the gba has a weird bug where if there are two overlapping obj pixels
        // that have differing priorities as specified in oam, and the one with lower priority is
        // nontransparent while the one with higher priority is transparent, the pixel with lower
        // priority is overwritten anyway. which is why we don't care if this obj pixel is transparent
        // or not, we just care about its priority

        if (scanline_compositing_info.obj_scanline[x].transparent ||
            priority < scanline_compositing_info.obj_scanline[x].priority) {
            scanline_compositing_info.obj_scanline[x].transparent = transparent;
            scanline_compositing_info.obj_scanline[x].index       = PaletteIndex(slot, index, true, false, 0, 0, 0);
            scanline_compositing_info.obj_scanline[x].priority    = priority;
            scanline_compositing_info.obj_semitransparent[x]      = semi_transparent;
        }
    }

    public void apply_horizontal_mosaic(int bg_mosaic, int obj_mosaic) {
        int mosaic_counter = 1;
        int mosaic_x       = 0;

        // mosaic is not applied often at all. lets check if its even applied in this scanline
        if (bg_mosaic != 1) {
            for (int x = 0; x < 240; x++) {
                mosaic_counter--;

                if (mosaic_counter == 0) {
                    mosaic_counter = bg_mosaic;
                    mosaic_x = x;
                }

                for (int bg = 0; bg < 4; bg++) {
                    if (ppu.backgrounds[bg].is_mosaic) scanline_compositing_info.bg_scanline[bg][x] = scanline_compositing_info.bg_scanline[bg][mosaic_x];
                }
            }
        } 

        mosaic_counter = 1;
        mosaic_x       = 0;

        if (obj_mosaic != 1) {
            for (int x = 0; x < 240; x++) {
                mosaic_counter--;

                if (mosaic_counter == 0) {
                    mosaic_counter = obj_mosaic;
                    mosaic_x = x;
                }

                scanline_compositing_info.obj_scanline[x] = scanline_compositing_info.obj_scanline[mosaic_x];
            }
        }
    }

    public void composite() {
        for (int scanline = 0; scanline < 192; scanline++) {
            ScanlineCompositingInfo* scanline_compositing_info = &scanline_compositing_infos[scanline];

            // step 1: sort the backgrounds by priority
            sorted_backgrounds = ppu.backgrounds;

            // insertion sort
            // the important part of insertion sort is that we need two backgrounds of the same priority
            // to be *also* sorted by index. i.e. if bg0 and bg1 had the same priorities, bg0 must appear
            // in sorted_backgrounds before bg1. insertion sort guarantees this.

            // https://www.geeksforgeeks.org/insertion-sort/
            for (int i = 1; i < 4; i++) {
                Background temp = sorted_backgrounds[i];
                int key = temp.priority;
                int j = i - 1;

                while (j >= 0 && sorted_backgrounds[j].priority > key) {
                    sorted_backgrounds[j + 1] = sorted_backgrounds[j];
                    j--;
                }
                sorted_backgrounds[j + 1] = temp;
            }


            // step 2: loop through the backgrounds, and get the first non transparent pixel
            WindowType default_window_type = (scanline_compositing_info.mmio_info.obj_window_enable || 
                                            scanline_compositing_info.mmio_info.windows[0].enabled || 
                                            scanline_compositing_info.mmio_info.windows[1].enabled)
                                            ? WindowType.OUTSIDE
                                            : WindowType.NONE;

            for (int x = 0; x < 256; x++) {
                // which window are we in?
                WindowType current_window_type = default_window_type;
                if (scanline_compositing_info.obj_window[x] && scanline_compositing_info.mmio_info.obj_window_enable) current_window_type = WindowType.OBJ;

                for (int i = 0; i < 2; i++) {
                    if (scanline_compositing_info.mmio_info.windows[i].enabled) {
                        if (scanline_compositing_info.mmio_info.windows[i].left <= x        && x        < scanline_compositing_info.mmio_info.windows[i].right  && 
                            scanline_compositing_info.mmio_info.windows[i].top  <= scanline && scanline < scanline_compositing_info.mmio_info.windows[i].bottom) {
                            current_window_type = cast(WindowType) i;
                            break;
                        }
                    }
                }

                // now that we know which window type we're in, let's calculate the color index for this pixel

                PaletteIndex[2] index = [PaletteIndex(-1, 0, false, false, 0, 0, 0), PaletteIndex(-1, 0, false, false, 0, 0, 0)];
                int priority = 4;

                int blendable_pixels = 0;
                int total_pixels = 0;
                bool processed_obj = false;
                bool force_blend = false;

                // i hate it here
                int current_bg_id;
                for (int i = 0; i < 4; i++) {
                    if (total_pixels == 2) break;

                    if (!processed_obj && !scanline_compositing_info.obj_scanline[x].transparent && is_obj_pixel_visible(current_window_type) &&
                            sorted_backgrounds[i].priority >= scanline_compositing_info.obj_scanline[x].priority) {
                        index[total_pixels] = scanline_compositing_info.obj_scanline[x].index;

                        processed_obj = true;
                        if (scanline_compositing_info.mmio_info.obj_target_pixel[total_pixels] || scanline_compositing_info.obj_semitransparent[x]) {
                            blendable_pixels++;
                            force_blend = scanline_compositing_info.obj_semitransparent[x] && total_pixels == 0;
                        }
                        total_pixels++;
                    }

                    if (total_pixels == 2) break;

                    current_bg_id = sorted_backgrounds[i].id;
                    if (!scanline_compositing_info.bg_scanline[current_bg_id][x].transparent) {
                        if (is_bg_pixel_visible(current_bg_id, current_window_type)) {
                            index[total_pixels] = scanline_compositing_info.bg_scanline[current_bg_id][x].index;
                            priority = sorted_backgrounds[i].priority;

                            if (scanline_compositing_info.mmio_info.bg_target_pixel[total_pixels][current_bg_id]) {
                                blendable_pixels++;
                                total_pixels++;
                                continue;
                            }
                            total_pixels++;
                            break; 
                        }
                    }

                    if (total_pixels == 2) break;
                }

                if (priority >= scanline_compositing_info.obj_scanline[x].priority && 
                    total_pixels < 2 && 
                    !processed_obj && 
                    !scanline_compositing_info.obj_scanline[x].transparent && 
                    is_obj_pixel_visible(current_window_type)) {
                    index[total_pixels] = scanline_compositing_info.obj_scanline[x].index;

                    if (scanline_compositing_info.mmio_info.obj_target_pixel[total_pixels] || scanline_compositing_info.obj_semitransparent[x]) {
                        blendable_pixels++;
                        force_blend = scanline_compositing_info.obj_semitransparent[x] && total_pixels == 0;
                    }
                    total_pixels++;
                }

                // add the backdrop
                if (total_pixels < 2) {
                    // total_pixels++; we can increment this, but it wont affect the rest of the loop
                    if (scanline_compositing_info.mmio_info.backdrop_target_pixel[blendable_pixels]) {
                        blendable_pixels++;
                    }
                }
                
                Blending effective_blending_type = is_blended(current_window_type) ? scanline_compositing_info.mmio_info.blending_type : Blending.NONE;
                if (force_blend) { effective_blending_type = Blending.ALPHA; }
                // now to blend the two values together
                pixels_output[x][scanline] = blend(index, blendable_pixels, effective_blending_type);
            }
        }
    }

    // blends the two colors together based on blending type
    private pragma(inline, true) Pixel blend(PaletteIndex[] index, int blendable_pixels, Blending effective_blending_type) {
        final switch (effective_blending_type) {
            case Blending.NONE:
                return index[0].resolve!E(pram_offset);

            case Blending.BRIGHTNESS_INCREASE:
                if (blendable_pixels < 1) goto case Blending.NONE;

                Pixel output = index[0].resolve!E(pram_offset);
                
                __m128i output__vec = _mm_loadu_si128(cast(__m128i*) &output);
                __m128i diff__vec = _mm_sub_epi8(_mm_set1_epi8(63), output__vec); 
                diff__vec = _mm_mullo_epi16(output__vec, _mm_set1_epi16(cast(short) scanline_compositing_info.mmio_info.evy_coeff));
                diff__vec = _mm_srli_epi16(diff__vec, 4);
                diff__vec = _mm_and_si128(diff__vec, _mm_set1_epi16(0xFF));
                output__vec = _mm_sub_epi16(output__vec, diff__vec);
                _mm_storeu_si128(cast(__m128i*) &output, output__vec);

                return output;

            case Blending.BRIGHTNESS_DECREASE:
                if (blendable_pixels < 1) goto case Blending.NONE;

                Pixel output = index[0].resolve!E(pram_offset);
                
                __m128i output__vec = _mm_loadu_si128(cast(__m128i*) &output);
                __m128i diff__vec = _mm_mullo_epi16(output__vec, _mm_set1_epi16(cast(short) scanline_compositing_info.mmio_info.evy_coeff));
                diff__vec = _mm_srli_epi16(diff__vec, 4);
                diff__vec = _mm_and_si128(diff__vec, _mm_set1_epi16(0xFF));
                output__vec = _mm_sub_epi16(output__vec, diff__vec);
                _mm_storeu_si128(cast(__m128i*) &output, output__vec);

                return output;

            case Blending.ALPHA:
                if (blendable_pixels < 2) goto case Blending.NONE;

                Pixel input_A = index[0].resolve!E(pram_offset);
                Pixel input_B = index[1].resolve!E(pram_offset);
                Pixel output;

                int effective_blend_a = scanline_compositing_info.mmio_info.blend_a;
                int effective_blend_b = scanline_compositing_info.mmio_info.blend_b;

                __m128i input_A__vec = _mm_loadu_si128(cast(__m128i*) &input_A);
                __m128i input_B__vec = _mm_loadu_si128(cast(__m128i*) &input_B); 

                static if (E == EngineType.A) {
                    if (scanline_compositing_info.mmio_info.bg_target_pixel[0][0]) {
                        effective_blend_a = input_A.a / 2;
                        effective_blend_b = 16 - (input_A.a / 2);
                    }
                }

                input_A__vec = _mm_mullo_epi16(input_A__vec, _mm_set1_epi16(cast(short) effective_blend_a));
                input_B__vec = _mm_mullo_epi16(input_B__vec, _mm_set1_epi16(cast(short) effective_blend_b));

                __m128i output__vec = _mm_add_epi16(input_A__vec, input_B__vec);
                output__vec = _mm_srli_epi16(output__vec, 4);
                output__vec = _mm_min_epi16(output__vec, _mm_set1_epi16(cast(short) 63));

                _mm_storeu_si128(cast(__m128i*) &output, output__vec);

                return output;
        }
    }

    private pragma(inline, true) bool is_blended(WindowType window_type) {
        final switch (window_type) {
            case WindowType.ZERO:    return scanline_compositing_info.mmio_info.windows[0].blended;
            case WindowType.ONE:     return scanline_compositing_info.mmio_info.windows[1].blended;
            case WindowType.OBJ:     return scanline_compositing_info.mmio_info.obj_window_blended;
            case WindowType.OUTSIDE: return scanline_compositing_info.mmio_info.outside_window_blended;
            case WindowType.NONE:    return true;
        }
    }
    
    // calculates if the bg pixel is visible under the effects of windowing
    private pragma(inline, true) bool is_bg_pixel_visible(int bg_id, WindowType window_type) {
        final switch (window_type) {
            case WindowType.ZERO:    return bit(scanline_compositing_info.mmio_info.windows[0].bg_enable,     bg_id);
            case WindowType.ONE:     return bit(scanline_compositing_info.mmio_info.windows[1].bg_enable,     bg_id);
            case WindowType.OBJ:     return bit(scanline_compositing_info.mmio_info.obj_window_bg_enable,     bg_id);
            case WindowType.OUTSIDE: return bit(scanline_compositing_info.mmio_info.outside_window_bg_enable, bg_id);
            case WindowType.NONE:    return true;
        }
    }
    
    // calculates if the obj pixel is visible under the effects of windowing
    private pragma(inline, true) bool is_obj_pixel_visible(WindowType window_type) {
        final switch (window_type) {
            case WindowType.ZERO:    return scanline_compositing_info.mmio_info.windows[0].obj_enable;
            case WindowType.ONE:     return scanline_compositing_info.mmio_info.windows[1].obj_enable;
            case WindowType.OBJ:     return scanline_compositing_info.mmio_info.obj_window_obj_enable;
            case WindowType.OUTSIDE: return scanline_compositing_info.mmio_info.outside_window_obj_enable;
            case WindowType.NONE:    return true;
        }
    }
}