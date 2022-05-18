module emu.hw.gpu.gpu3d.rendering_engine;

import emu;
import util;

struct AnnotatedPolygon {
    Polygon orig;
    float high_y;
    float mid_y;
    float low_y;
    float high_y_x;
    float mid_y_x;
    float low_y_x;
    float high_mid_slope;
    float mid_low_slope;
    float high_low_slope;
    bool mid_on_left;
    Vertex[3] viewport_coords;
}

final class RenderingEngine {

    GPU3D parent;

    int num_polygons = 0;

    Pixel[] scanline;

    AnnotatedPolygon[0x1000] annotated_polygons;

    this(GPU3D parent) {
        this.parent = parent;
    }

//   screen_x = (xx+ww)*viewport_width / (2*ww) + viewport_x1
//   screen_y = (yy+ww)*viewport_height / (2*ww) + viewport_y1

    void vblank() {
        annotate_polygons();
    }

    float to_screen_coords_x(float x, float w) {
        return ((x + w) * (parent.viewport_x2 - parent.viewport_x1) / (cast(float) (2 * w)) + cast(float) parent.viewport_x1);
    }

    float to_screen_coords_y(float y, float w) {
        return ((y + w) * (parent.viewport_y2 - parent.viewport_y1) / (cast(float) (2 * w)) + cast(float) parent.viewport_y1);
    }

    float get_slope(float dy, float dx) {
        if (dx == 0) return 256.0f;
        if (dy == 0) return 0.0001f;
        return dy / dx;
    }

    void annotate_polygons() {
        for (int i = 0; i < num_polygons; i++) {
            auto p = parent.rendering_buffer[i];
            Vertex[3] sorted_vertices;
            for (int j = 0; j < 3; j++) {
                sorted_vertices[j] = Vertex(Vec4([
                        to_screen_coords_x(p.vertices[j].pos[0], p.vertices[j].pos[3]),
                        to_screen_coords_y(p.vertices[j].pos[1], p.vertices[j].pos[3]),
                        0.0f,
                        0.0f,
                    ]),
                    p.vertices[j].r,
                    p.vertices[j].g,
                    p.vertices[j].b
                );
            }

            // bubble sort
            int j = 0;
            int k = 0;
            for (j = 0; j < 3; j++) {
                for (k = 0; k < 3 - j - 1; k++) {
                    if (sorted_vertices[k].pos[1] > sorted_vertices[k + 1].pos[1]) {
                        Vertex temp = sorted_vertices[k];
                        sorted_vertices[k] = sorted_vertices[k + 1];
                        sorted_vertices[k + 1] = temp;
                    }
                }
            }
            
            auto high_y  = sorted_vertices[2].pos[1];
            auto mid_y   = sorted_vertices[1].pos[1];
            auto low_y   = sorted_vertices[0].pos[1];
            auto high_yx = sorted_vertices[2].pos[0];
            auto mid_yx  = sorted_vertices[1].pos[0];
            auto low_yx  = sorted_vertices[0].pos[0];

            auto high_mid_slope = get_slope(high_y - mid_y, high_yx - mid_yx);
            auto mid_low_slope  = get_slope(mid_y  - low_y, mid_yx  - low_yx);
            auto high_low_slope = get_slope(high_y - low_y, high_yx - low_yx);

            annotated_polygons[i] = AnnotatedPolygon(
                p,
                high_y,
                mid_y,
                low_y,
                high_yx,
                mid_yx,
                low_yx,
                high_mid_slope,
                mid_low_slope,
                high_low_slope,
                (mid_y - low_y) * get_slope(high_yx - low_yx, high_y - low_y) + low_yx > mid_yx,
                sorted_vertices
            );
        }
    }

    float[3] get_interpolation_weights(float x1, float x2, float x3, float y1, float y2, float y3, float px, float py) {
        float w1 = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        float w2 = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        float w3 = 1 - w1 - w2;
        return [w1, w2, w3];
    }

    float interpolate(float[3] weights, float a1, float a2, float a3) {
        return weights[0] * a1 + weights[1] * a2 + weights[2] * a3;
    }

    // ya this is NOT correct at all and WILL break games (e.g. mario kart).
    // TODO: make the timings of the rendering engine actually decent
    void render(int scanline) {
        auto effective_scanline = 192 - scanline;

        for (int i = 0; i < num_polygons; i++) {
            AnnotatedPolygon p = annotated_polygons[i];

            if (effective_scanline <= p.high_y && effective_scanline >= p.low_y) {
                float start_x;
                float end_x;

                if (effective_scanline >= p.mid_y) {
                    if (p.mid_on_left) {
                        start_x = (effective_scanline - p.mid_y) / p.high_mid_slope + p.mid_y_x;
                        end_x   = (effective_scanline - p.low_y) / p.high_low_slope + p.low_y_x;
                    } else {
                        end_x   = (effective_scanline - p.mid_y) / p.high_mid_slope + p.mid_y_x;
                        start_x = (effective_scanline - p.low_y) / p.high_low_slope + p.low_y_x;
                    }
                } else {
                    if (p.mid_on_left) {
                        start_x = (effective_scanline - p.mid_y) / p.mid_low_slope + p.mid_y_x;
                        end_x   = (effective_scanline - p.low_y) / p.high_low_slope + p.low_y_x;
                    } else {
                        end_x   = (effective_scanline - p.mid_y) / p.mid_low_slope + p.mid_y_x;
                        start_x = (effective_scanline - p.low_y) / p.high_low_slope + p.low_y_x;
                    }
                }

                if (start_x < 0)   start_x = 0;
                if (start_x > 256) start_x = 256;
                if (end_x < 0)     end_x = 0;
                if (end_x > 256)   end_x = 256;

                for (int x = cast(int) start_x; x < cast(int) end_x; x++) {
                    auto interpolation_weights = get_interpolation_weights(
                        p.viewport_coords[0].pos[0],
                        p.viewport_coords[1].pos[0],
                        p.viewport_coords[2].pos[0],
                        p.viewport_coords[0].pos[1],
                        p.viewport_coords[1].pos[1],
                        p.viewport_coords[2].pos[1],
                        x,
                        effective_scanline
                    );

                    int r, g, b, a;
                    
                    if (p.orig.uses_textures) {
                        auto s = interpolate(
                            interpolation_weights,
                            p.orig.vertices[0].texcoord[0],
                            p.orig.vertices[1].texcoord[0],
                            p.orig.vertices[2].texcoord[0],
                        );

                        auto t = interpolate(
                            interpolation_weights,
                            p.orig.vertices[0].texcoord[1],
                            p.orig.vertices[1].texcoord[1],
                            p.orig.vertices[2].texcoord[1],
                        );

                        auto color = get_color_from_texture(cast(int) s, cast(int) t, p);
                        r = cast(int) color[0];
                        g = cast(int) color[1];
                        b = cast(int) color[2];
                        a = cast(int) color[3];
                    } else {
                        r = cast(int) interpolate(
                            interpolation_weights,
                            p.viewport_coords[0].r,
                            p.viewport_coords[1].r,
                            p.viewport_coords[2].r,
                        );

                        g = cast(int) interpolate(
                            interpolation_weights,
                            p.viewport_coords[0].g,
                            p.viewport_coords[1].g,
                            p.viewport_coords[2].g,
                        );

                        b = cast(int) interpolate(
                            interpolation_weights,
                            p.viewport_coords[0].b,
                            p.viewport_coords[1].b,
                            p.viewport_coords[2].b,
                        );

                        a = 31;
                    }

                    gpu_engine_a.ppu.canvas.draw_3d_pixel(x, cast(int) r, cast(int) g, cast(int) b);
                }
            }
            // foreach (v; parent.rendering_buffer[i].vertices) {
            //     auto sus = v.pos;


            //     int screen_x = cast(int) ((sus[0] + sus[3]) * (parent.viewport_x2 - parent.viewport_x1) / (cast(float) (2 * sus[3])) + cast(float) parent.viewport_x1);
            //     int screen_y = cast(int) ((sus[1] + sus[3]) * (parent.viewport_y2 - parent.viewport_y1) / (cast(float) (2 * sus[3])) + cast(float) parent.viewport_y1);
            //     log_gpu3d("stinky render: %f %f %f %f %f %f %f %f -> %f %f", sus[0], sus[1], sus[2], sus[3], parent.viewport_x2, parent.viewport_x1, parent.viewport_y2, parent.viewport_y1, screen_x, screen_y);
            //     if (cast(int) (192 - screen_y) == scanline) {
            //         gpu_engine_a.ppu.canvas.draw_3d_pixel(cast(int) screen_x, 0, 0, 0);
            //     }
            // }
        }
    }
}