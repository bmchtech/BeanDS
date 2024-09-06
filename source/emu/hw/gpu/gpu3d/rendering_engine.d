module emu.hw.gpu.gpu3d.rendering_engine;

import core.sync.condition;
import core.sync.mutex;
import core.thread;
import emu.hw.gpu.gpu3d.gpu3d;
import emu.hw.gpu.gpu3d.math;
import emu.hw.gpu.gpu3d.polygon;
import emu.hw.gpu.gpu3d.texture;
import emu.hw.gpu.gpu3d.textureblending;
import emu.hw.gpu.pixel;
import emu.hw.memory.strategy.memstrategy;
import std.algorithm;
import util;

import emu.hw.input.key_input;

bool deboog = false;

alias AnnotatedPolygon = RenderingEngine.AnnotatedPolygon;

final class RenderingEngine {
    struct AnnotatedPolygon {
        struct AnnotatedVertex {
            int index;
            bool left;
        }

        this(Polygon!Point_20_12 p, RenderingEngine rendering_engine) {
            this.orig = p;

            for (int i = 0; i < p.num_vertices; i++) {
                viewport_coords[i] = Point_14_18([
                    rendering_engine.to_screen_coords_x(this.orig.vertices[i].pos[0], this.orig.vertices[i].pos[3]),
                    rendering_engine.to_screen_coords_y(this.orig.vertices[i].pos[1], this.orig.vertices[i].pos[3]),
                    this.orig.vertices[i].pos[2].saturating_convert!(14, 18),
                    this.orig.vertices[i].pos[3].saturating_convert!(14, 18)
                ]);

                // log_gpu3d("coord: (%f, %f)", cast(float) viewport_coords[i][0], cast(float) viewport_coords[i][1]);

                // if (viewport_coords[i][0])
            }

                log_gpu3d("Computing cockwise...");
                log_gpu3d("4 chunks: %f %f %f %f", 
                cast(float) (this.orig.vertices[1].pos[1] - this.orig.vertices[0].pos[1]),
                cast(float) (this.orig.vertices[2].pos[0] - this.orig.vertices[1].pos[0]),
                cast(float) (this.orig.vertices[1].pos[0] - this.orig.vertices[0].pos[0]),
                cast(float) (this.orig.vertices[2].pos[1] - this.orig.vertices[1].pos[1])
                );
            this.clockwise = (
                    (cast(float) viewport_coords[1][1] - cast(float) viewport_coords[0][1]) * (cast(float) viewport_coords[2][0] - cast(float) viewport_coords[1][0]) -
                    (cast(float) viewport_coords[1][0] - cast(float) viewport_coords[0][0]) * (cast(float) viewport_coords[2][1] - cast(float) viewport_coords[1][1])
                ) > 0;

            int topleft_vertex_index  = 0;
            int botright_vertex_index = 0;
            int topright_vertex_index = 0;
            int botleft_vertex_index  = 0;

            for (int j = 1; j < p.num_vertices; j++) {
                float topleft_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[topleft_vertex_index][0];
                float topleft_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[topleft_vertex_index][1];
                float botright_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[botright_vertex_index][0];
                float botright_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[botright_vertex_index][1];
                float topright_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[topright_vertex_index][0];
                float topright_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[topright_vertex_index][1];
                float botleft_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[botleft_vertex_index][0];
                float botleft_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[botleft_vertex_index][1];

                if (topleft_dy > 0 || (topleft_dy == 0 && topleft_dx < 0)) topleft_vertex_index = j;
                if (botright_dy < 0 || (botright_dy == 0 && botright_dx > 0)) botright_vertex_index = j;
                if (topright_dy > 0 || (topright_dy == 0 && topright_dx > 0)) topright_vertex_index = j;
                if (botleft_dy < 0 || (botleft_dy == 0 && botleft_dx < 0)) botleft_vertex_index = j;
            }
                log_gpu3d("topleft: %d, botright: %d, topright: %d, botleft: %d", topleft_vertex_index, botright_vertex_index, topright_vertex_index, botleft_vertex_index);
                log_gpu3d("cockwise: %d", clockwise);

            annotated_vertices[orig.num_vertices - 1].left = annotated_vertices[orig.num_vertices - 2].left;

            annotated_vertices[0] = AnnotatedVertex(topleft_vertex_index, clockwise);
            top_y = cast(int) viewport_coords[topleft_vertex_index][1];
            bot_y_lower = cast(int) viewport_coords[botright_vertex_index][1];

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

            log_nds("starting at %x %x", inc_index, dec_index);
            int i = 2;
            while (!inc_has_reached_destination || !dec_has_reached_destination) {
                if (dec_has_reached_destination && !inc_has_reached_destination) {
                    log_nds("dec has reached destination. stepping inc...");
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
                    log_nds("inc has reached destination. stepping dec...");
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
                        log_nds("inc is lower than dec. stepping inc...");
                        annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                        prev_dec_index = dec_index;
                        dec_has_reached_destination = dec_index == botright_vertex_index;
                        // if (!dec_has_reached_destination) {
                            dec_index--;
                            if (dec_index == -1) dec_index = orig.num_vertices - 1;
                            i++;
                        // }
                    } else {
                        log_nds("inc is >= than dec. stepping dec...");
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

                log_nds("inc: %x, dec: %x", inc_index, dec_index);
            }
            // log_gpu3d("starting at %x %x", annotated_vertices[j].index);

            bot_y = viewport_coords[left_index][1] > viewport_coords[right_index][1] ? cast(int) viewport_coords[left_index][1] : cast(int) viewport_coords[right_index][1];
            if (bot_y < 0) bot_y = 0;
            if (bot_y > 191) bot_y = 191;
            if (top_y < 0) top_y = 0;
            if (top_y > 255) top_y = 255;

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
        int bot_y_lower;
        
        Polygon!Point_20_12 orig;
        bool clockwise;
        Point_14_18[10] viewport_coords;
    }

    GPU3D parent;

    int num_polygons = 0;

    Pixel[] scanline;

    AnnotatedPolygon[0x10000] annotated_polygons;

    Mutex     start_rendering_mutex;
    Condition start_rendering_condvar;
    Thread    rendering_thread;

    Mutex     rendering_scanline_mutex;
    int       rendering_scanline;
    bool      is_rendering;

    TextureResolver texture_resolver;

    this(GPU3D parent, Mem mem) {
        this.parent = parent;
        this.start_rendering_mutex    = new Mutex();
        this.start_rendering_condvar  = new Condition(start_rendering_mutex);
        this.rendering_thread         = new Thread(&rendering_thread_handler).start();
        this.rendering_scanline_mutex = new Mutex();
        this.is_rendering             = false;
        this.texture_resolver         = new TextureResolver(mem);
    }

    void vblank() {
        annotate_polygons();
    }

    Coord_14_18 get_slope(Coord_14_18 dy, Coord_14_18 dx) {
        if (dx == 0) return Coord_14_18.from_repr(0x7FFFFFFF);
        if (dy == 0) return Coord_14_18.from_repr(0x00000001);
        return dy / dx;
    }

//     # intersection function
// def isect_line_plane_v3(p0, p1, p_co, p_no, epsilon=1e-6):
//     """
//     p0, p1: Define the line.
//     p_co, p_no: define the plane:
//         p_co Is a point on the plane (plane coordinate).
//         p_no Is a normal vector defining the plane direction;
//              (does not need to be normalized).

//     Return a Vector or None (when the intersection can't be found).
//     """

//     u = sub_v3v3(p1, p0)
//     dot = dot_v3v3(p_no, u)

//     if abs(dot) > epsilon:
//         # The factor of the point between p0 -> p1 (0 - 1)
//         # if 'fac' is between (0 - 1) the point intersects with the segment.
//         # Otherwise:
//         #  < 0.0: behind p0.
//         #  > 1.0: infront of p1.
//         w = sub_v3v3(p0, p_co)
//         fac = -dot_v3v3(p_no, w) / dot
//         u = mul_v3_fl(u, fac)
//         return add_v3v3(p0, u)

//     # The segment is parallel to plane.
//     return None


    enum Plane {
        TOP,
        BOTTOM,
        LEFT,
        RIGHT,
        NEAR,
        FAR
    }

    void clip_against_plane(Plane plane)(Polygon!Point_20_12 polygon) {     
        static if (plane == Plane.TOP) {
            enum idx1 = 0;
            enum idx2 = 1;
            enum w_mul = 1;
        }

        static if (plane == Plane.BOTTOM) {
            enum idx1 = 1;
            enum idx2 = 2;
            enum w_mul = -1;
        }

        static if (plane == Plane.LEFT) {
            enum idx1 = 2;
            enum idx2 = 0;
            enum w_mul = -1;
        }

        static if (plane == Plane.RIGHT) {
            enum idx1 = 3;
            enum idx2 = 1;
            enum w_mul = 1;
        }

        static if (plane == Plane.NEAR) {
            enum idx1 = 2;
            enum idx2 = 3;
            enum w_mul = -1;
        }

        static if (plane == Plane.FAR) {
            enum idx1 = 0;
            enum idx2 = 2;
            enum w_mul = 1;
        }


        auto calculate_region = (Point_20_12 endpoint) {
            int region = 0;
            if (endpoint[idx1] < endpoint[3] * w_mul) region |= 0b0001;
            if (endpoint[idx1] > endpoint[3] * w_mul) region |= 0b0010;
            if (endpoint[idx2] < endpoint[3] * w_mul) region |= 0b0100;
            if (endpoint[idx2] > endpoint[3] * w_mul) region |= 0b1000;
            return region;
        };

        int vertex_count = 0;
        Point_20_12[10] clipped_vertices;
        int[2] regions;
        Point_20_12[2] endpoints;
        regions[0] = calculate_region(endpoints[0]);
        for (int i = 0; i < polygon.num_vertices; i++) {
            auto vertex = polygon.vertices[i];
            log_nds("Clipping vertex...");
            endpoints[1] = vertex.pos;
            regions[1] = calculate_region(endpoints[1]);

            if (regions[0] == 0 && regions[1] == 0) {
                log_nds("Trivially accept");
                // Nothing to do
                clipped_vertices[vertex_count] = endpoints[0];
                vertex_count++;
            } else if ((regions[0] & regions[1]) != 0) {
                // Trivially reject
                log_nds("Trivially reject");
                continue;

            } else {
                log_nds("Clipping...");
                for (int j = 0; j < 2; j++) {
                    if (regions[j] == 0) {
                        clipped_vertices[vertex_count] = endpoints[j];
                        vertex_count++;
                        continue;
                    }

                    float x0 = cast(float) endpoints[0][idx1];
                    float y0 = cast(float) endpoints[0][idx2];
                    float x1 = cast(float) endpoints[1][idx1];
                    float y1 = cast(float) endpoints[1][idx2];
                    float x;
                    float y;

                    float boundary = cast(float) endpoints[j][3] * w_mul;
                    if (regions[j] & 1) {           // point is above the clip window
                        x = x0 + (x1 - x0) * (boundary - y0) / (y1 - y0);
                        y = boundary;
                    } else if (regions[j] & 2) { // point is below the clip window
                        x = x0 + (x1 - x0) * (-boundary - y0) / (y1 - y0);
                        y = -boundary;
                    } else if (regions[j] & 4) {  // point is to the right of clip window
                        y = y0 + (y1 - y0) * (boundary - x0) / (x1 - x0);
                        x = boundary;
                    } else if (regions[j] & 8) {   // point is to the left of clip window
                        y = y0 + (y1 - y0) * (-boundary - x0) / (x1 - x0);
                        x = -boundary;
                    }

                    Point_20_12 clipped_vertex = endpoints[j];
                    clipped_vertex[idx1] = FixedPoint!(20, 12)(x);
                    clipped_vertex[idx2] = FixedPoint!(20, 12)(y);
                    clipped_vertices[vertex_count] = clipped_vertex;
                    vertex_count++;
                }
            }
        }

        log_nds("Clipped to %d vertices", vertex_count);

        for (int i = 0; i < vertex_count; i++) {
            polygon.vertices[i].pos = clipped_vertices[i];
        }

        polygon.num_vertices = vertex_count;
    }

    void clip() {
        for (int i = 0; i < num_polygons; i++) {

        // for (int i = 7; i < 8; i++) {
            bool polygon_needs_clipping = false;
            auto polygon = parent.rendering_buffer[i];

            for (int j = 0; j < polygon.num_vertices; j++) {
                if (polygon.vertices[j].pos[0] < -1 || polygon.vertices[j].pos[0] > 1 || polygon.vertices[j].pos[1] < -1 || polygon.vertices[j].pos[1] > 1) {
                    polygon_needs_clipping = true;
                    break;
                }
            }

            if (!polygon_needs_clipping) continue;

            log_nds("Clipping polygon %d", i);
            clip_against_plane!(Plane.TOP)(polygon);
            clip_against_plane!(Plane.BOTTOM)(polygon);
            clip_against_plane!(Plane.LEFT)(polygon);
            clip_against_plane!(Plane.RIGHT)(polygon);
            clip_against_plane!(Plane.NEAR)(polygon);
            clip_against_plane!(Plane.FAR)(polygon);
            log_nds("Clipped polygon %d", i);
        }
    }

    void annotate_polygons() {
        for (int i = 0; i < num_polygons; i++) {

        // for (int i = 7; i < 8 && i < num_polygons; i++) {
            // log_gpu3d("Annotating Polygon #%d!", i);
            deboog = i == 4;
            annotated_polygons[i] = AnnotatedPolygon(parent.rendering_buffer[i], this);
        }
    }

    Coord_14_18 to_screen_coords_x(Coord_20_12 x, Coord_20_12 w) {
        log_gpu3d("x: %f, wprime: %f, parent.viewport_y1: %f, parent.viewport_y2: %f", cast(float) x, cast(float) w, cast(float) parent.viewport_y1, cast(float) parent.viewport_y2);
        return ((x + w) * ((parent.viewport_x2 - parent.viewport_x1) / (w * 2)) + parent.viewport_x1).saturating_convert!(14, 18);
    }

    Coord_14_18 to_screen_coords_y(Coord_20_12 y, Coord_20_12 w) {
        log_gpu3d("y: %f, wprime: %f, parent.viewport_y1: %f, parent.viewport_y2: %f", cast(float) y, cast(float) w, cast(float) parent.viewport_y1, cast(float) parent.viewport_y2);
        log_gpu3d("interim result: %f", cast(float) w * 2);
        log_gpu3d("interim result: %f", cast(float) (parent.viewport_y2 - parent.viewport_y1));
        log_gpu3d("interim result: %f",cast(float) ((parent.viewport_y2 - parent.viewport_y1) / (w.abs() * 2)));
        log_gpu3d("interim result: %f", cast(float) ((y + w.abs()) * ((parent.viewport_y2 - parent.viewport_y1) / (w.abs() * 2))));
        return ((y + w.abs()) * ((parent.viewport_y2 - parent.viewport_y1) / (w.abs() * 2)) + parent.viewport_y1).saturating_convert!(14, 18);
    }

    Coord_14_18[3] get_interpolation_weights(Coord_14_18 x1, Coord_14_18 x2, Coord_14_18 x3, Coord_14_18 y1, Coord_14_18 y2, Coord_14_18 y3, Coord_14_18 px, Coord_14_18 py) {
        Coord_14_18 w1 = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        Coord_14_18 w2 = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        Coord_14_18 w3 = 1 - w1 - w2;
        return [w1, w2, w3];
    }

    // tysm https://melonds.kuribo64.net/comments.php?id=85
    // not a perfect implementation of the above yet but... 
    // TODO???: maybe make interpolation more accurate?
    Coord_14_18 get_interpolation_factor(Coord_14_18 xmax, Coord_14_18 x, Coord_14_18 w0, Coord_14_18 w1) {
        if ((xmax - x) + x == 0) return Coord_14_18(0.0f);
        return ((xmax - x) * 1) / ((xmax - x) * 1 + x * 1);
    }

    Coord_14_18 interpolate(T)(T a0, T a1, Coord_14_18 factor) {
        return (1 - factor) * a0 + factor * a1;
    }

    void rendering_thread_handler() {
        try {
        while (true) {
            start_rendering_mutex.lock();
                start_rendering_condvar.wait();
            start_rendering_mutex.unlock();
                
            rendering_scanline_mutex.lock();
                rendering_scanline = -1;
                is_rendering       = true;
            rendering_scanline_mutex.unlock();
            
            rendering_scanline_mutex.lock();
                for (int i = 0; i < num_polygons; i++) {
                    for (int j = 0; j < parent.rendering_buffer[i].num_vertices; j++) {
                        auto w = parent.rendering_buffer[i].vertices[j].pos[3];
                        w = w < 0 ? -w : w;
                        parent.rendering_buffer[i].vertices[j].pos[3] = w;
                    }
                }
                clip();
                annotate_polygons();
                render();
                is_rendering = false;
            rendering_scanline_mutex.unlock();
        }
        } catch (Throwable t) {
            import std.stdio;
            writeln(t);
            error_gpu3d("Rendering thread crashed.");
        }
    }

    void begin_rendering_frame() {
        start_rendering_mutex.lock();
            start_rendering_condvar.notify();
        start_rendering_mutex.unlock();
    }

    void wait_for_rendering_to_finish() {
        if (!rendering_thread.isRunning) {
            error_gpu3d("The rendering thread has died. This is a bug.");
        }

        while (true) {
            rendering_scanline_mutex.lock();
                if (!is_rendering) {
                    rendering_scanline_mutex.unlock();
                    return;
                }
            rendering_scanline_mutex.unlock();
        }
    }

    // ya this is NOT correct at all and WILL break games (e.g. mario kart).
    // TODO: make the timings of the rendering engine actually decent
    void render() {
        parent.start_rendering();

        for (int i = 0; i < num_polygons; i++) {
        // for (int i = 7; i < 8 && i < num_polygons; i++) {
            log_gpu3d("POLYGON %d", i);
            log_gpu3d("    uses_textures               : %d", parent.geometry_buffer[i].uses_textures               );
            log_gpu3d("    texture_vram_offset         : %x", parent.geometry_buffer[i].texture_vram_offset         );
            log_gpu3d("    texture_repeat_s_direction  : %d", parent.geometry_buffer[i].texture_repeat_s_direction  );
            log_gpu3d("    texture_repeat_t_direction  : %d", parent.geometry_buffer[i].texture_repeat_t_direction  );
            log_gpu3d("    texture_flip_s_direction    : %d", parent.geometry_buffer[i].texture_flip_s_direction    );
            log_gpu3d("    texture_flip_t_direction    : %d", parent.geometry_buffer[i].texture_flip_t_direction    );
            log_gpu3d("    texture_s_size              : %d", parent.geometry_buffer[i].texture_s_size              );
            log_gpu3d("    texture_t_size              : %d", parent.geometry_buffer[i].texture_t_size              );
            log_gpu3d("    texture_format              : %s", parent.geometry_buffer[i].texture_format              );
            log_gpu3d("    texture_color_0_transparent : %d", parent.geometry_buffer[i].texture_color_0_transparent );
            log_gpu3d("    palette_base_address        : %x", parent.geometry_buffer[i].palette_base_address        );
            log_gpu3d("    num_vertices                : %d", parent.geometry_buffer[i].num_vertices                );
            log_gpu3d("    vertex #0                   : %f %f %f %f", cast(float) parent.geometry_buffer[i].vertices[0].pos[0], cast(float) parent.geometry_buffer[i].vertices[0].pos[1], cast(float) parent.geometry_buffer[i].vertices[0].pos[2], cast(float) parent.geometry_buffer[i].vertices[0].pos[3]);
            log_gpu3d("    vertex #1                   : %f %f %f %f", cast(float) parent.geometry_buffer[i].vertices[1].pos[0], cast(float) parent.geometry_buffer[i].vertices[1].pos[1], cast(float) parent.geometry_buffer[i].vertices[1].pos[2], cast(float) parent.geometry_buffer[i].vertices[1].pos[3]);
            log_gpu3d("    vertex #2                   : %f %f %f %f", cast(float) parent.geometry_buffer[i].vertices[2].pos[0], cast(float) parent.geometry_buffer[i].vertices[2].pos[1], cast(float) parent.geometry_buffer[i].vertices[2].pos[2], cast(float) parent.geometry_buffer[i].vertices[2].pos[3]);
            log_gpu3d("    vertex #3                   : %f %f %f %f", cast(float) parent.geometry_buffer[i].vertices[3].pos[0], cast(float) parent.geometry_buffer[i].vertices[3].pos[1], cast(float) parent.geometry_buffer[i].vertices[3].pos[2], cast(float) parent.geometry_buffer[i].vertices[3].pos[3]);
            log_gpu3d("    annotated vertex 0          : %f %f %f %f", cast(float) annotated_polygons[i].viewport_coords[0][0], cast(float) annotated_polygons[i].viewport_coords[0][1], cast(float) annotated_polygons[i].viewport_coords[0][2], cast(float) annotated_polygons[i].viewport_coords[0][3]);
            log_gpu3d("    annotated vertex 1          : %f %f %f %f", cast(float) annotated_polygons[i].viewport_coords[1][0], cast(float) annotated_polygons[i].viewport_coords[1][1], cast(float) annotated_polygons[i].viewport_coords[1][2], cast(float) annotated_polygons[i].viewport_coords[1][3]);
            log_gpu3d("    annotated vertex 2          : %f %f %f %f", cast(float) annotated_polygons[i].viewport_coords[2][0], cast(float) annotated_polygons[i].viewport_coords[2][1], cast(float) annotated_polygons[i].viewport_coords[2][2], cast(float) annotated_polygons[i].viewport_coords[2][3]);
            log_gpu3d("    annotated vertex 3          : %f %f %f %f", cast(float) annotated_polygons[i].viewport_coords[3][0], cast(float) annotated_polygons[i].viewport_coords[3][1], cast(float) annotated_polygons[i].viewport_coords[3][2], cast(float) annotated_polygons[i].viewport_coords[3][3]);
            // log_gpu3d("rendering funky polygon #%d", i);
            auto p = annotated_polygons[i];

            auto effective_top_y = clamp(p.top_y, 0, 191);
            auto effective_bot_y = clamp(p.bot_y, 0, 191);

            // log_gpu3d("determined. do we even render? %d >= %d >= %d. (%d %d)", p.top_y, 0, p.bot_y, effective_top_y, effective_bot_y);

            for (int effective_scanline = effective_top_y; effective_scanline >= effective_bot_y; effective_scanline--) {
                auto left_xy  = [p.viewport_coords[p.left_index] [0], p.viewport_coords[p.left_index] [1]];
                auto right_xy = [p.viewport_coords[p.right_index][0], p.viewport_coords[p.right_index][1]];

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
                
                log_gpu3d("indices: %d %d %d %d", p.previous_left_index, p.left_index, p.right_index, p.previous_right_index);
                log_gpu3d("effective scanline: %d", effective_scanline);
                log_gpu3d("determined start x: %f", cast(float) start_x);
                log_gpu3d("determined end x: %f", cast(float) end_x);
                log_gpu3d("left_xy: (%f %f)", cast(float) left_xy[0], cast(float) left_xy[1]);
                log_gpu3d("right_xy: (%f %f)", cast(float) right_xy[0], cast(float) right_xy[1]);
                   log_gpu3d("determined slopes: (left: %f, right: %f)", 
                    cast(float) get_slope(
                        p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                        p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                    ),
                    cast(float) get_slope(
                        p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                        p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    )
                );
                log_gpu3d("determined components to calculate left slope: (%f %f), (%f %f)", 
                    cast(float) p.viewport_coords[p.previous_left_index][0].to_unsigned_float,
                    cast(float) p.viewport_coords[p.previous_left_index][1].to_unsigned_float,
                    cast(float) p.viewport_coords[p.left_index][0].to_unsigned_float,
                    cast(float) p.viewport_coords[p.left_index][1].to_unsigned_float
                );
                log_gpu3d("determined components to calculate right slope: (%f %f), (%f %f)", 
                    cast(float) p.viewport_coords[p.previous_right_index][0].to_unsigned_float,
                    cast(float) p.viewport_coords[p.previous_right_index][1].to_unsigned_float,
                    cast(float) p.viewport_coords[p.right_index][0].to_unsigned_float,
                    cast(float) p.viewport_coords[p.right_index][1].to_unsigned_float
                );             
                // log_gpu3d("determined slopes: (left: %f, right: %f)", 
                //     cast(float) get_slope(
                //         p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                //         p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                //     ),
                //     cast(float) get_slope(
                //         p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                //         p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                //     )
                // );
                // log_gpu3d("determined components to calculate left slope: (%f %f), (%f %f)", 
                //     cast(float) p.viewport_coords[p.previous_left_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.previous_left_index][1].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.left_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.left_index][1].to_unsigned_float
                // );
                // log_gpu3d("determined components to calculate right slope: (%f %f), (%f %f)", 
                //     cast(float) p.viewport_coords[p.previous_right_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.previous_right_index][1].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.right_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.right_index][1].to_unsigned_float
                // );

                int effective_start_x = start_x.integral_part;
                int effective_end_x   = end_x.integral_part;

                if (start_x < 0)   effective_start_x = 0;
                if (start_x > 255) effective_start_x = 256;
                if (end_x < 0)     effective_end_x = -1;
                if (end_x > 255)   effective_end_x = 255;

                if (effective_start_x == 0 && effective_end_x == 0) {
                    // log_gpu3d("bug!");

                    // log_gpu3d("determined slopes: (left: %f, right: %f)", 
                    //     cast(float) get_slope(
                    //         p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                    //         p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                    //     ),
                    //     cast(float) get_slope(
                    //         p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                    //         p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    //     )
                    // );
                    // log_gpu3d("determined components to calculate left slope: (%f %f), (%f %f)", 
                    //     cast(float) p.viewport_coords[p.previous_left_index][0].to_unsigned_float,
                    //     cast(float) p.viewport_coords[p.previous_left_index][1].to_unsigned_float,
                    //     cast(float) p.viewport_coords[p.left_index][0].to_unsigned_float,
                    //     cast(float) p.viewport_coords[p.left_index][1].to_unsigned_float
                    // );
                    // log_gpu3d("determined components to calculate right slope: (%f %f), (%f %f)", 
                    //     cast(float) p.viewport_coords[p.previous_right_index][0].to_unsigned_float,
                    //     cast(float) p.viewport_coords[p.previous_right_index][1].to_unsigned_float,
                    //     cast(float) p.viewport_coords[p.right_index][0].to_unsigned_float,
                    //     cast(float) p.viewport_coords[p.right_index][1].to_unsigned_float
                    // );
                    // log_gpu3d("the sussy subtractions: %s %s %s %s", 
                    //     p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1],
                    //     p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0],
                    //     p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1],
                    //     p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    // );
                }
                log_gpu3d("%x => %x (%x => %x)", effective_start_x, effective_end_x, start_x.integral_part, end_x.integral_part);
                auto factor_l = get_interpolation_factor(
                    p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1],
                    effective_scanline - p.viewport_coords[p.left_index][1],
                    p.viewport_coords[p.previous_left_index][3],
                    p.viewport_coords[p.left_index][3]
                );

                auto factor_r = get_interpolation_factor(
                    p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1],
                    effective_scanline - p.viewport_coords[p.right_index][1],
                    p.viewport_coords[p.previous_right_index][3],
                    p.viewport_coords[p.right_index][3]
                );

                    auto w_l = interpolate(p.viewport_coords[p.previous_left_index][3], p.viewport_coords[p.left_index][3], factor_l);
                    auto w_r = interpolate(p.viewport_coords[p.previous_right_index][3], p.viewport_coords[p.right_index][3], factor_r);
                    auto z_l = interpolate(p.viewport_coords[p.previous_left_index][2], p.viewport_coords[p.left_index][2], factor_l);
                    auto z_r = interpolate(p.viewport_coords[p.previous_right_index][2], p.viewport_coords[p.right_index][2], factor_r);
                log_gpu3d("scanline: %d w_l: %f, w_r: %f, z_l: %f, z_r: %f", effective_scanline, cast(float) w_l, cast(float) w_r, cast(float) z_l, cast(float) z_r);


                for (int x = effective_start_x; x <= effective_end_x; x++) {

                    auto factor_scanline = get_interpolation_factor(
                        Coord_14_18(cast(int) end_x - cast(int) start_x),
                        Coord_14_18(x - cast(int) start_x),
                        w_l,
                        w_r
                    );

                    // TODO: this is a hack to work around polygon clipping! when we implement that, we can remove this
                    if (factor_scanline < 0 || factor_scanline > 1) factor_scanline = Coord_14_18(0); // error_gpu3d("calculating factor scanline: %d %d %d %f %f %f", cast(int) end_x, cast(int) start_x, cast(int) x, cast(float) w_l, cast(float) w_r, cast(float) factor_scanline);

                    factor_l = clamp(factor_l, Coord_14_18(0.0f), Coord_14_18(1.0f));
                    factor_r = clamp(factor_r, Coord_14_18(0.0f), Coord_14_18(1.0f));

                    auto r_l = interpolate(p.orig.vertices[p.previous_left_index].r << 4, p.orig.vertices[p.left_index].r << 4, factor_l);
                    auto r_r = interpolate(p.orig.vertices[p.previous_right_index].r << 4, p.orig.vertices[p.right_index].r << 4, factor_r);
                    auto g_l = interpolate(p.orig.vertices[p.previous_left_index].g << 4, p.orig.vertices[p.left_index].g << 4, factor_l);
                    auto g_r = interpolate(p.orig.vertices[p.previous_right_index].g << 4, p.orig.vertices[p.right_index].g << 4, factor_r);
                    auto b_l = interpolate(p.orig.vertices[p.previous_left_index].b << 4, p.orig.vertices[p.left_index].b << 4, factor_l);
                    auto b_r = interpolate(p.orig.vertices[p.previous_right_index].b << 4, p.orig.vertices[p.right_index].b << 4, factor_r);

                    int r = cast(int) interpolate(r_l, r_r, 1 - factor_scanline) >> 3;
                    int g = cast(int) interpolate(g_l, g_r, 1 - factor_scanline) >> 3;
                    int b = cast(int) interpolate(b_l, b_r, 1 - factor_scanline) >> 3;
                    int a = p.orig.alpha;

                    if (p.orig.uses_textures) {
                        auto texcoord_s_l = interpolate(p.orig.vertices[p.previous_left_index].texcoord[0].convert!(14, 18), p.orig.vertices[p.left_index].texcoord[0].convert!(14, 18), factor_l);
                        auto texcoord_s_r = interpolate(p.orig.vertices[p.previous_right_index].texcoord[0].convert!(14, 18), p.orig.vertices[p.right_index].texcoord[0].convert!(14, 18), factor_r);
                        auto texcoord_t_l = interpolate(p.orig.vertices[p.previous_left_index].texcoord[1].convert!(14, 18), p.orig.vertices[p.left_index].texcoord[1].convert!(14, 18), factor_l);
                        auto texcoord_t_r = interpolate(p.orig.vertices[p.previous_right_index].texcoord[1].convert!(14, 18), p.orig.vertices[p.right_index].texcoord[1].convert!(14, 18), factor_r);

                        auto texcoord_s = interpolate(texcoord_s_l, texcoord_s_r, 1 - factor_scanline);
                        auto texcoord_t = interpolate(texcoord_t_l, texcoord_t_r, 1 - factor_scanline);
                        
                        auto color = texture_resolver.get_color_from_texture(cast(int) texcoord_s, cast(int) texcoord_t, p, p.orig.palette_base_address);
                        
//             if ((input.keys & DSKeyCode.DOWN) == 0 && i == 4) {
// log_gpu3d("(%x %x %x %x) = texture_resolver.get_color_from_texture(%x %x %x %x, %x, %x, %x)", r, g, b, a, texcoord_s_l, texcoord_s_r, texcoord_t_l, texcoord_t_r, cast(int) texcoord_s, cast(int) texcoord_t, p.orig.palette_base_address);
//             }
                        
                        int tex_r = cast(int) color[0] << 1;
                        int tex_g = cast(int) color[1] << 1;
                        int tex_b = cast(int) color[2] << 1;
                        int tex_a = cast(int) color[3];


                        int old_r = r;
                        int old_g = g;
                        int old_b = b;

                        final switch (p.orig.texture_blending_mode) {
                            case TextureBlendingMode.MODULATION:

                            case TextureBlendingMode.DECAL:
                            case TextureBlendingMode.TOON:
                            case TextureBlendingMode.HIGHLIGHT:
                                r = tex_r;
                                g = tex_g;
                                b = tex_b;
                                a = tex_a;
                                break;
                        }
                    }
                
                    // TODO: we will only need either z or w, never both. only calculate the one we need (assuming interpolation is a bottleneck)
                    Coord_14_18 z = interpolate(z_l, z_r, 1 - factor_scanline);
                    Coord_14_18 w = interpolate(w_l, w_r, 1 - factor_scanline);
                    parent.plot(191 - effective_scanline, Pixel(r, g, b, a), x, z, w);
                }

                log_nds("scanline: %d p.bot_y: %d p.top_y: %d", effective_scanline, p.bot_y, p.top_y);

                for (int limit = 0; limit < 2 && effective_scanline == p.bot_y; limit++) {
                    p.top_y = p.bot_y;

                    if (p.annotated_vertices[p.annotated_vertex_next].left) {
                        p.previous_left_index = p.left_index;
                        p.left_index = p.annotated_vertices[p.annotated_vertex_next].index;
                    } else {
                        p.previous_right_index = p.right_index;
                        p.right_index = p.annotated_vertices[p.annotated_vertex_next].index;
                    }

                    p.bot_y = max(cast(int) p.viewport_coords[p.left_index][1], cast(int) p.viewport_coords[p.right_index][1]);
                    effective_bot_y = max(p.bot_y, 0);
                    p.annotated_vertex_next++;

                    log_gpu3d("[top: %d, bot: %d]", p.top_y, p.bot_y);
                    log_gpu3d("[left: %d -> %d, right: %d -> %d]", p.previous_left_index, p.left_index, p.previous_right_index, p.right_index);

                    log_gpu3d("determined annotated vertex next: %d, %d, %d, %d, %d", p.annotated_vertex_next, p.top_y, p.bot_y, p.left_index, p.right_index);
                }
            }

            annotated_polygons[i] = p;
        }
        
        parent.stop_rendering_scanline();
    }
}