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

    GPU3DCommandManager command_manager;

    this() {
        gpu3d = this;

        command_manager = new GPU3DCommandManager();
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
}