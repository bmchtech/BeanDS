module emu.hw.gpu.gpu3d.gpu3d;

import emu;
import util;

__gshared GPU3D gpu3d;
final class GPU3D {

    ShadingType polygon_attribute_shading;
    bool enable_texture_mapping;
    bool enable_alpha_test;
    bool enable_alpha_blending;
    bool enable_anti_aliasing;
    bool enable_edge_marking;
    bool enable_fog_color;
    bool enable_fog;
    int fog_depth_shift;
    bool color_buffer_rdlines_underflow;
    bool polygon_vertex_ram_overflow;
    bool rear_plane_mode;

    GeometryEngine geometry_engine;
    RenderingEngine rendering_engine;

    int viewport_x1;
    int viewport_y1;
    int viewport_x2;
    int viewport_y2;

    // TODO: how big is this really?
    Polygon[0x1000] polygon_ram_1;
    Polygon[0x1000] polygon_ram_2;
    Polygon* geometry_buffer;
    Polygon* rendering_buffer;

    Pixel[256][48] scanline_cache;

    int scanline_cache_head = 0;
    int scanline_cache_tail = 0;

    this() {
        gpu3d = this;

        geometry_engine = new GeometryEngine(this);
        rendering_engine = new RenderingEngine(this);

        geometry_buffer  = cast(Polygon*) &polygon_ram_1;
        rendering_buffer = cast(Polygon*) &polygon_ram_2;
    }

    void vblank() {
        scanline_cache_head = 0;
        scanline_cache_tail = 0;
    }

    void render(int scanline) {
        rendering_engine.render(scanline);
    }

    void plot(Pixel p, int x) {
        scanline_cache[scanline_cache_head][x] = p;
    }

    void start_rendering_scanline() {
        for (int x = 0; x < 256; x++) {
            scanline_cache[scanline_cache_head][x] = Pixel(0, 0, 0);
        }
    }

    void stop_rendering_scanline() {
        scanline_cache_head++;
        if (scanline_cache_head == 48) scanline_cache_head = 0;
    }

    void draw_scanline_to_canvas() {
        int y = scanline_cache_head + 1;
        if (y == 48) y = 0;
        for (int x = 0; x < 256; x++) {
            gpu_engine_a.ppu.canvas.draw_3d_pixel(x, scanline_cache[scanline_cache_tail][x]);
        }

        scanline_cache_tail++;
        if (scanline_cache_tail == 48) scanline_cache_tail = 0;
    }

    void swap_buffers(int num_polygons) {
        auto temp = geometry_buffer;
        geometry_buffer = rendering_buffer;
        rendering_buffer = temp;

        rendering_engine.num_polygons = num_polygons;
        rendering_engine.annotate_polygons();
    }

    Byte read_DISP3DCNT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0] = enable_texture_mapping;
                result[1] = polygon_attribute_shading;
                result[2] = enable_alpha_test;
                result[3] = enable_alpha_blending;
                result[4] = enable_anti_aliasing;
                result[5] = enable_edge_marking;
                result[6] = enable_edge_marking;
                result[7] = enable_fog;
                break;
            
            case 1:
                result[0..3] = fog_depth_shift;
                result[4]    = color_buffer_rdlines_underflow;
                result[5]    = polygon_attribute_shading;
                result[6]    = rear_plane_mode;
        }

        return result;
    }

    void write_DISP3DCNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                enable_texture_mapping    = data[0];
                polygon_attribute_shading = cast(ShadingType) data[1];
                enable_alpha_test         = data[2];
                enable_alpha_blending     = data[3];
                enable_anti_aliasing      = data[4];
                enable_edge_marking       = data[5];
                enable_fog_color          = data[6];
                enable_fog                = data[7];
                break;

            case 1:
                fog_depth_shift                = data[0..3];
                color_buffer_rdlines_underflow &= !data[4];
                polygon_vertex_ram_overflow    &= !data[5];

                // TODO: this variable might need its own enum, but idk what this value is used for yet, so
                // i'll just use a normal boolean for now for DISP3DCNT reads. i'll repurpose this when i figure
                // out how the 3D GPU actually works
                rear_plane_mode = data[6];
                break;
        }
    }

    Byte read_GXSTAT(int target_byte) {
        return Word(0x00600000).get_byte(target_byte);
    }

    void write_GXSTAT(int target_byte, Byte data) {
        
    }
}