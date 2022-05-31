module emu.hw.gpu.gpu3d.rendering_engine;

import std.algorithm;

import emu;
import util;

alias AnnotatedPolygon = RenderingEngine.AnnotatedPolygon;

final class RenderingEngine {
    struct AnnotatedPolygon {
        struct AnnotatedVertex {
            int index;
            bool left;
        }

        this(Polygon p, RenderingEngine rendering_engine) {
            this.orig = p;

            for (int i = 0; i < p.num_vertices; i++) {
                viewport_coords[i] = Vec4([
                    rendering_engine.to_screen_coords_x(p.vertices[i].pos[0], p.vertices[i].pos[3]),
                    rendering_engine.to_screen_coords_y(p.vertices[i].pos[1], p.vertices[i].pos[3]),
                    0.0f,
                    0.0f
                ]);
            }

            this.clockwise = (
                (p.vertices[1].pos[0] - p.vertices[0].pos[0]) * (p.vertices[2].pos[1] - p.vertices[0].pos[1]) -
                (p.vertices[1].pos[1] - p.vertices[1].pos[0]) * (p.vertices[2].pos[0] - p.vertices[0].pos[0])
            ) < 0;

            int topleft_vertex_index  = 0;
            int botright_vertex_index = 0;
            int topright_vertex_index = 0;
            int botleft_vertex_index  = 0;

            for (int j = 1; j < p.num_vertices; j++) {
                auto topleft_dx = viewport_coords[j][0] - viewport_coords[topleft_vertex_index][0];
                auto topleft_dy = viewport_coords[j][1] - viewport_coords[topleft_vertex_index][1];
                auto botright_dx = viewport_coords[j][0] - viewport_coords[botright_vertex_index][0];
                auto botright_dy = viewport_coords[j][1] - viewport_coords[botright_vertex_index][1];
                auto topright_dx = viewport_coords[j][0] - viewport_coords[topright_vertex_index][0];
                auto topright_dy = viewport_coords[j][1] - viewport_coords[topright_vertex_index][1];
                auto botleft_dx = viewport_coords[j][0] - viewport_coords[botleft_vertex_index][0];
                auto botleft_dy = viewport_coords[j][1] - viewport_coords[botleft_vertex_index][1];
                if (topleft_dy > 0 || (topleft_dy == 0 && topleft_dx < 0)) topleft_vertex_index = j;
                if (botright_dy < 0 || (botright_dy == 0 && botright_dx > 0)) botright_vertex_index = j;
                if (topright_dy > 0 || (topright_dy == 0 && topright_dx > 0)) topright_vertex_index = j;
                if (botleft_dy < 0 || (botleft_dy == 0 && botleft_dx < 0)) botleft_vertex_index = j;
            }

            annotated_vertices[orig.num_vertices - 1].left = annotated_vertices[orig.num_vertices - 2].left;

            annotated_vertices[0] = AnnotatedVertex(topleft_vertex_index, clockwise);
            top_y = cast(int) viewport_coords[topleft_vertex_index][1];

            int max_left_vertex_y  = cast(int) viewport_coords[botright_vertex_index][1];
            int max_right_vertex_y = cast(int) viewport_coords[botright_vertex_index][1];
            int max_left_vertex_index = topleft_vertex_index + (clockwise ? -1 : 1);
            int max_right_vertex_index = topright_vertex_index + (clockwise ? 1 : -1);
            if (max_left_vertex_index >= orig.num_vertices) max_left_vertex_index = 0;
            if (max_left_vertex_index < 0) max_left_vertex_index = orig.num_vertices - 1;
            if (max_right_vertex_index >= orig.num_vertices) max_right_vertex_index = 0;
            if (max_right_vertex_index < 0) max_right_vertex_index = orig.num_vertices - 1;

            left_index  = max_left_vertex_index;
            right_index = max_right_vertex_index;
            previous_left_index  = topleft_vertex_index;
            previous_right_index = topright_vertex_index;

            uint dec_index = clockwise ? left_index : right_index;
            uint inc_index = clockwise ? right_index : left_index;
            uint prev_inc_index = inc_index;
            uint prev_dec_index = dec_index;
            inc_index++;
            dec_index--;

            if (dec_index == -1) dec_index = p.num_vertices - 1;
            if (inc_index == p.num_vertices) inc_index = 0;
            
            bool inc_has_reached_destination = false;
            bool dec_has_reached_destination = false;

            int i = 2;
            while (!inc_has_reached_destination || !dec_has_reached_destination) {
                if (dec_has_reached_destination && !inc_has_reached_destination) {
                    annotated_vertices[i] = AnnotatedVertex(inc_index, !clockwise);
                    prev_inc_index = inc_index;
                    inc_has_reached_destination = inc_index == botright_vertex_index;
                    inc_index++;
                    if (inc_index == p.num_vertices) inc_index = 0;
                    i++;
                } else

                if (inc_has_reached_destination && !dec_has_reached_destination) {
                    annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                    prev_dec_index = dec_index;
                    dec_has_reached_destination = dec_index == botright_vertex_index;
                    dec_index--;
                    if (dec_index == -1) dec_index = orig.num_vertices - 1;
                    i++;
                } else

                {
                    if (viewport_coords[prev_inc_index][1] < viewport_coords[prev_dec_index][1]) {
                        annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                        prev_dec_index = dec_index;
                        dec_has_reached_destination = dec_index == botright_vertex_index;
                        dec_index--;
                        if (dec_index == -1) dec_index = orig.num_vertices - 1;
                        i++;
                    } else {
                        annotated_vertices[i] = AnnotatedVertex(inc_index, !clockwise);
                        prev_inc_index = inc_index;
                        inc_has_reached_destination = inc_index == botright_vertex_index;
                        inc_index++;
                        if (inc_index == p.num_vertices) inc_index = 0;
                        i++;
                    }
                }
            }

            bot_y = viewport_coords[left_index][1] > viewport_coords[right_index][1] ? cast(int) viewport_coords[left_index][1] : cast(int) viewport_coords[right_index][1];
            annotated_vertex_next = 2;
        }

        int annotated_vertex_next;
        AnnotatedVertex[10] annotated_vertices;
        int previous_left_index;
        int previous_right_index;
        int left_index;
        int right_index;
        int top_y;
        int bot_y;
        
        Polygon orig;
        bool clockwise;
        Vec4[10] viewport_coords;
    }

    GPU3D parent;

    int num_polygons = 0;

    Pixel[] scanline;

    AnnotatedPolygon[0x1000] annotated_polygons;

    this(GPU3D parent) {
        this.parent = parent;
    }

    void vblank() {
        annotate_polygons();
    }

    float get_slope(float dy, float dx) {
        if (dx == 0) return 256.0f;
        if (dy == 0) return 0.001f;
        return dy / dx;
    }

    void annotate_polygons() {
        for (int i = 0; i < num_polygons; i++) {
            annotated_polygons[i] = AnnotatedPolygon(parent.rendering_buffer[i], this);
        }
    }


    float to_screen_coords_x(float x, float w) {
        return ((x + w) * (parent.viewport_x2 - parent.viewport_x1) / (cast(float) (2 * w)) + cast(float) parent.viewport_x1);
    }

    float to_screen_coords_y(float y, float w) {
        return ((y + w) * (parent.viewport_y2 - parent.viewport_y1) / (cast(float) (2 * w)) + cast(float) parent.viewport_y1);
    }

    float[3] get_interpolation_weights(float x1, float x2, float x3, float y1, float y2, float y3, float px, float py) {
        float w1 = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        float w2 = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        float w3 = 1 - w1 - w2;
        return [w1, w2, w3];
    }

    // tysm https://melonds.kuribo64.net/comments.php?id=85
    // not a perfect implementation of the above yet but... 
    // TODO???: maybe make interpolation more accurate?
    float get_interpolation_factor(float xmax, float x, float w0, float w1) {
        return ((xmax - x) * w1) / ((xmax - x) * w1 + x * w0);
    }

    float interpolate(float a0, float a1, float factor) {
        return (1 - factor) * a0 + factor * a1;
    }

    // ya this is NOT correct at all and WILL break games (e.g. mario kart).
    // TODO: make the timings of the rendering engine actually decent
    void render(int scanline) {
        auto effective_scanline = 192 - scanline;

        for (int i = 0; i < num_polygons; i++) {
            auto p = annotated_polygons[i];
            auto left_xy  = p.viewport_coords[p.left_index] [0..2];
            auto right_xy = p.viewport_coords[p.right_index][0..2];

            if (p.top_y >= effective_scanline && effective_scanline >= p.bot_y) {
                auto start_x = (effective_scanline - cast(int) left_xy[1]) / 
                    get_slope(
                        p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                        p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                    ) + cast(int) left_xy[0];

                auto end_x = (effective_scanline - cast(int) right_xy[1]) / 
                    get_slope(
                        p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                        p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    ) + cast(int) right_xy[0];

                import std.math;
                if (std.math.isNaN(start_x) || std.math.isNaN(end_x)) error_gpu3d("bad.");

                if (start_x < 0)   start_x = 0;
                if (start_x > 256) start_x = 256;
                if (end_x < 0)     end_x = 0;
                if (end_x > 256)   end_x = 256;
                
                auto factor_l = get_interpolation_factor(
                    cast(int) p.viewport_coords[p.previous_left_index][1] - cast(int) p.viewport_coords[p.left_index][1],
                    cast(int) effective_scanline - p.viewport_coords[p.left_index][1],
                    p.orig.vertices[p.previous_left_index].pos[3],
                    p.orig.vertices[p.left_index].pos[3]
                );

                auto factor_r = get_interpolation_factor(
                    cast(int) p.viewport_coords[p.previous_right_index][1] - cast(int) p.viewport_coords[p.right_index][1],
                    effective_scanline - cast(int) p.viewport_coords[p.right_index][1],
                    p.orig.vertices[p.previous_right_index].pos[3],
                    p.orig.vertices[p.right_index].pos[3]
                );

                for (int x = cast(int) start_x; x < cast(int) end_x; x++) {

                    auto w_l = interpolate(p.orig.vertices[p.previous_left_index].pos[3], p.orig.vertices[p.left_index].pos[3], 1-factor_l);
                    auto w_r = interpolate(p.orig.vertices[p.previous_right_index].pos[3], p.orig.vertices[p.right_index].pos[3], 1-factor_r);
                    auto r_l = interpolate(p.orig.vertices[p.previous_left_index].r, p.orig.vertices[p.left_index].r, factor_l);
                    auto r_r = interpolate(p.orig.vertices[p.previous_right_index].r, p.orig.vertices[p.right_index].r, factor_r);
                    auto g_l = interpolate(p.orig.vertices[p.previous_left_index].g, p.orig.vertices[p.left_index].g, factor_l);
                    auto g_r = interpolate(p.orig.vertices[p.previous_right_index].g, p.orig.vertices[p.right_index].g, factor_r);
                    auto b_l = interpolate(p.orig.vertices[p.previous_left_index].b, p.orig.vertices[p.left_index].b, factor_l);
                    auto b_r = interpolate(p.orig.vertices[p.previous_right_index].b, p.orig.vertices[p.right_index].b, factor_r);

                    auto factor_scanline = get_interpolation_factor(
                        cast(int) end_x - cast(int) start_x,
                        x - cast(int) start_x,
                        w_l,
                        w_r
                    );

                    log_gpu3d("The result of interpolation: %f %f %d %f %f %f", end_x, start_x, x, w_l, w_r, factor_scanline);

                    auto r = interpolate(r_l, r_r, 1-factor_scanline);
                    auto g = interpolate(g_l, g_r, 1-factor_scanline);
                    auto b = interpolate(b_l, b_r, 1-factor_scanline);
                    gpu_engine_a.ppu.canvas.draw_3d_pixel(x, cast(int) r, cast(int) g, cast(int) b);
                }
            }

            if (effective_scanline == p.bot_y) {
                p.top_y = p.bot_y;

                if (p.annotated_vertices[p.annotated_vertex_next].left) {
                    p.previous_left_index = p.left_index;
                    p.left_index = p.annotated_vertices[p.annotated_vertex_next].index;
                } else {
                    p.previous_right_index = p.right_index;
                    p.right_index = p.annotated_vertices[p.annotated_vertex_next].index;
                }

                p.bot_y = cast(int) max(p.viewport_coords[p.left_index][1], p.viewport_coords[p.right_index][1]);
                p.annotated_vertex_next++;
            }

            annotated_polygons[i] = p;
        }
    }
}