module emu.hw.gpu.gpu3d.rendering_engine;

import std.algorithm;

import emu;
import util;


bool deboog = false;

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
                viewport_coords[i] = Point([
                    rendering_engine.to_screen_coords_x(p.vertices[i].pos[0], p.vertices[i].pos[3]),
                    rendering_engine.to_screen_coords_y(p.vertices[i].pos[1], p.vertices[i].pos[3]),
                    p.vertices[i].pos[2],
                    p.vertices[i].pos[3]
                ]);

                if (deboog) log_gpu3d("[DEBOOG]    funnycoords: (%f, %f)", cast(float) viewport_coords[i][0], cast(float) viewport_coords[i][1]);

                // // log_gpu3d("coord: (%s, %s)", viewport_coords[i][0], viewport_coords[i][1]);

                // if (viewport_coords[i][0])
            }

            this.clockwise = (
                    (p.vertices[1].pos[1] - p.vertices[0].pos[1]) * (p.vertices[2].pos[0] - p.vertices[1].pos[0]) -
                    (p.vertices[1].pos[0] - p.vertices[0].pos[0]) * (p.vertices[2].pos[1] - p.vertices[1].pos[1])
                ) > 0; //(
                // (p.vertices[1].pos[0] - p.vertices[0].pos[0]) * (p.vertices[2].pos[1] - p.vertices[0].pos[1]) -
                // (p.vertices[1].pos[1] - p.vertices[1].pos[0]) * (p.vertices[2].pos[0] - p.vertices[0].pos[0])
            // ) < 0;

            // if (deboog) // log_gpu3d("[DEBOOG] cockwise: %x %s", this.clockwise,
            //     (
            //         (p.vertices[1].pos[1] - p.vertices[0].pos[1]) * (p.vertices[2].pos[0] - p.vertices[1].pos[0]) -
            //         (p.vertices[1].pos[0] - p.vertices[0].pos[0]) * (p.vertices[2].pos[1] - p.vertices[1].pos[1])
            //     )
            // );

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
            top_y = viewport_coords[topleft_vertex_index][1].integral_part;

            int max_left_vertex_y  = viewport_coords[botright_vertex_index][1].integral_part;
            int max_right_vertex_y = viewport_coords[botright_vertex_index][1].integral_part;
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
                    // if (!inc_has_reached_destination) {
                        inc_index++;
                        if (inc_index == p.num_vertices) inc_index = 0;
                        i++;
                    // }
                } else

                if (inc_has_reached_destination && !dec_has_reached_destination) {
                    annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                    prev_dec_index = dec_index;
                    dec_has_reached_destination = dec_index == botright_vertex_index;
                    // if (!dec_has_reached_destination) {
                        dec_index--;
                        if (dec_index == -1) dec_index = orig.num_vertices - 1;
                        i++;
                    // }
                } else

                {
                    if (viewport_coords[prev_inc_index][1] < viewport_coords[prev_dec_index][1]) {
                        annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                        prev_dec_index = dec_index;
                        dec_has_reached_destination = dec_index == botright_vertex_index;
                        // if (!dec_has_reached_destination) {
                            dec_index--;
                            if (dec_index == -1) dec_index = orig.num_vertices - 1;
                            i++;
                        // }
                    } else {
                        annotated_vertices[i] = AnnotatedVertex(inc_index, !clockwise);
                        prev_inc_index = inc_index;
                        inc_has_reached_destination = inc_index == botright_vertex_index;
                        // if (!inc_has_reached_destination) {
                            inc_index++;
                            if (inc_index == p.num_vertices) inc_index = 0;
                            i++;
                        // }
                    }
                }
            }


            for (int j = 0; j < p.num_vertices + 2; j++) {
                // if (deboog)
                    // log_gpu3d("[DEBOOG] annotatedcoords: %d %s", annotated_vertices[j].index, annotated_vertices[j].left ? "left" : "right");

                // // log_gpu3d("coord: (%s, %s)", viewport_coords[i][0], viewport_coords[i][1]);

                // if (viewport_coords[i][0])
            }

            // if (deboog) // log_gpu3d("[DEBOOG] BOT_Y OPTIONS! %s %s", viewport_coords[inc_index][1], viewport_coords[dec_index][1]);
            bot_y = viewport_coords[left_index][1] > viewport_coords[right_index][1] ? viewport_coords[left_index][1].integral_part : viewport_coords[right_index][1].integral_part;
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
        Point[10] viewport_coords;
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

    Coordinate get_slope(Coordinate dy, Coordinate dx) {
        if (dx == 0) return Coordinate(256.0f);
        if (dy == 0) return Coordinate(0.001f);
        return dy / dx;
    }

    void annotate_polygons() {
        // // log_gpu3d("annotating %x polygons", num_polygons);
        for (int i = 0; i < num_polygons; i++) {
            log_gpu3d("Annotating Polygon #%d!", i);
            deboog = true || i == 1;
            annotated_polygons[i] = AnnotatedPolygon(parent.rendering_buffer[i], this);
        }
    }

    Coordinate to_screen_coords_x(Coordinate x, Coordinate w) {
        return ((x + w) * (parent.viewport_x2 - parent.viewport_x1) / (w * 2) + parent.viewport_x1);
    }

    Coordinate to_screen_coords_y(Coordinate y, Coordinate w) {
        return ((y + w) * (parent.viewport_y2 - parent.viewport_y1) / (w * 2) + parent.viewport_y1);
    }

    Coordinate[3] get_interpolation_weights(Coordinate x1, Coordinate x2, Coordinate x3, Coordinate y1, Coordinate y2, Coordinate y3, Coordinate px, Coordinate py) {
        Coordinate w1 = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        Coordinate w2 = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        Coordinate w3 = 1 - w1 - w2;
        return [w1, w2, w3];
    }

    // tysm https://melonds.kuribo64.net/comments.php?id=85
    // not a perfect implementation of the above yet but... 
    // TODO???: maybe make interpolation more accurate?
    Coordinate get_interpolation_factor(Coordinate xmax, Coordinate x, Coordinate w0, Coordinate w1) {
        return ((xmax - x) * 1) / ((xmax - x) * 1 + x * 1);
    }

    Coordinate interpolate(T)(T a0, T a1, Coordinate factor) {
        return (1 - factor) * a0 + factor * a1;
    }

    // ya this is NOT correct at all and WILL break games (e.g. mario kart).
    // TODO: make the timings of the rendering engine actually decent
    void render(int scanline) {
        if (scanline == 0) {
            annotate_polygons();
        }
        
        parent.start_rendering_scanline();
        
        auto effective_scanline = 192 - scanline;

        // if (num_polygons>15) num_polygons = 15;

        for (int i = 0; i < num_polygons; i++) {
            // log_gpu3d("rendering funky polygon #%d", i);
            auto p = annotated_polygons[i];
            auto left_xy  = p.viewport_coords[p.left_index] [0..2];
            auto right_xy = p.viewport_coords[p.right_index][0..2];

            // log_gpu3d("determined. do we even render? %d >= %d >= %d.", p.top_y, effective_scanline, p.bot_y);
            if (p.top_y >= effective_scanline && effective_scanline >= p.bot_y) {
                auto start_x = (effective_scanline - left_xy[1].integral_part) / 
                    get_slope(
                        p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                        p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                    ) + left_xy[0].integral_part;

                auto end_x = (effective_scanline - right_xy[1].integral_part) / 
                    get_slope(
                        p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                        p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    ) + right_xy[0].integral_part;

                // log_gpu3d("determined slopes: (left: %s, right: %s)", 
                //     get_slope(
                //         p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                //         p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                //     ),
                //     get_slope(
                //         p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                //         p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                //     )
                // );
                // log_gpu3d("determined components to calculate left slope: (%s %s), (%s %s)", 
                //     p.viewport_coords[p.previous_left_index][0],
                //     p.viewport_coords[p.previous_left_index][1],
                //     p.viewport_coords[p.left_index][0],
                //     p.viewport_coords[p.left_index][1]
                // );
                // log_gpu3d("determined components to calculate right slope: (%s %s), (%s %s)", 
                //     p.viewport_coords[p.previous_right_index][0],
                //     p.viewport_coords[p.previous_right_index][1],
                //     p.viewport_coords[p.right_index][0],
                //     p.viewport_coords[p.right_index][1]
                // );

                int effective_start_x = start_x.integral_part;
                int effective_end_x   = end_x.integral_part;

                if (start_x < 0)   effective_start_x = 0;
                if (start_x > 256) effective_start_x = 256;
                if (end_x < 0)     effective_end_x = 0;
                if (end_x > 256)   effective_end_x = 256;

                // log_gpu3d("determined startx and endx: %d %d (%s %s)", effective_start_x, effective_end_x, start_x, end_x);
                
                auto factor_l = get_interpolation_factor(
                    p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1],
                    effective_scanline - p.viewport_coords[p.left_index][1],
                    p.orig.vertices[p.previous_left_index].pos[3],
                    p.orig.vertices[p.left_index].pos[3]
                );

                auto factor_r = get_interpolation_factor(
                    p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1],
                    effective_scanline - p.viewport_coords[p.right_index][1],
                    p.orig.vertices[p.previous_right_index].pos[3],
                    p.orig.vertices[p.right_index].pos[3]
                );

                for (int x = effective_start_x; x < effective_end_x; x++) {
                    auto w_l = interpolate(p.orig.vertices[p.previous_left_index].pos[3], p.orig.vertices[p.left_index].pos[3], factor_l);
                    auto w_r = interpolate(p.orig.vertices[p.previous_right_index].pos[3], p.orig.vertices[p.right_index].pos[3], factor_r);

                    auto factor_scanline = get_interpolation_factor(
                        Coordinate(end_x.integral_part - start_x.integral_part),
                        Coordinate(x - start_x.integral_part),
                        w_l,
                        w_r
                    );

                    int r;
                    int g;
                    int b;
                    int a = 0;

                    if (p.orig.uses_textures) {
                        auto texcoord_s_l = interpolate(p.orig.vertices[p.previous_left_index].texcoord[0], p.orig.vertices[p.left_index].texcoord[0], factor_l);
                        auto texcoord_s_r = interpolate(p.orig.vertices[p.previous_right_index].texcoord[0], p.orig.vertices[p.right_index].texcoord[0], factor_r);
                        auto texcoord_t_l = interpolate(p.orig.vertices[p.previous_left_index].texcoord[1], p.orig.vertices[p.left_index].texcoord[1], factor_l);
                        auto texcoord_t_r = interpolate(p.orig.vertices[p.previous_right_index].texcoord[1], p.orig.vertices[p.right_index].texcoord[1], factor_r);

                        auto texcoord_s = interpolate(texcoord_s_l, texcoord_s_r, 1 - factor_scanline);
                        auto texcoord_t = interpolate(texcoord_t_l, texcoord_t_r, 1 - factor_scanline);
                        
                        auto color = get_color_from_texture(texcoord_s.integral_part, texcoord_t.integral_part, p, p.orig.palette_base_address);
                        r = cast(int) color[0] << 1;
                        g = cast(int) color[1] << 1;
                        b = cast(int) color[2] << 1;
                        a = cast(int) color[3];
                    } else {
                        auto r_l = interpolate(p.orig.vertices[p.previous_left_index].r << 4, p.orig.vertices[p.left_index].r << 4, factor_l);
                        auto r_r = interpolate(p.orig.vertices[p.previous_right_index].r << 4, p.orig.vertices[p.right_index].r << 4, factor_r);
                        auto g_l = interpolate(p.orig.vertices[p.previous_left_index].g << 4, p.orig.vertices[p.left_index].g << 4, factor_l);
                        auto g_r = interpolate(p.orig.vertices[p.previous_right_index].g << 4, p.orig.vertices[p.right_index].g << 4, factor_r);
                        auto b_l = interpolate(p.orig.vertices[p.previous_left_index].b << 4, p.orig.vertices[p.left_index].b << 4, factor_l);
                        auto b_r = interpolate(p.orig.vertices[p.previous_right_index].b << 4, p.orig.vertices[p.right_index].b << 4, factor_r);

                        // // // log_gpu3d("The result of interpolation: %s %s %d %s %s %s", end_x, start_x, x, w_l, w_r, factor_scanline);

                        r = interpolate(r_l, r_r, 1 - factor_scanline).integral_part >> 3;
                        g = interpolate(g_l, g_r, 1 - factor_scanline).integral_part >> 3;
                        b = interpolate(b_l, b_r, 1 - factor_scanline).integral_part >> 3;
                        a = 31;
                    }
                
                    // TODO: we will only need either z or w, never both. only calculate the one we need (assuming interpolation is a bottleneck)
                    Coordinate z = 0; // ill implement you later.
                    Coordinate w = interpolate(w_l, w_r, 1 - factor_scanline);
                    parent.plot(Pixel(r, g, b, a), x, z, w);
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

                p.bot_y = max(p.viewport_coords[p.left_index][1], p.viewport_coords[p.right_index][1]).integral_part;
                p.annotated_vertex_next++;

                // log_gpu3d("determined annotated vertex next: %d, %d, %d, %d, %d", p.annotated_vertex_next, p.top_y, p.bot_y, p.left_index, p.right_index);
            }

            annotated_polygons[i] = p;
        }
            
        parent.stop_rendering_scanline();
    }
}