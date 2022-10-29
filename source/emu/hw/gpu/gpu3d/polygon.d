module emu.hw.gpu.gpu3d.polygon;

import emu.hw.gpu.gpu3d.math;
import emu.hw.gpu.gpu3d.texture;

import util;

struct Vertex(T) {
    T pos;
    int r;
    int g;
    int b;
    T texcoord;
}

struct Polygon(T) {
    Vertex!T[10] vertices; // max-gon is ten-gon
    int num_vertices;

    bool uses_textures;

    int texture_vram_offset;
    bool texture_repeat_s_direction;
    bool texture_repeat_t_direction;
    bool texture_flip_s_direction;
    bool texture_flip_t_direction;
    int texture_s_size;
    int texture_t_size;
    TextureFormat texture_format;
    bool texture_color_0_transparent;
    Word palette_base_address;
}

interface PolygonAssembler {
    bool submit_vertex(Vertex!Point_20_12 vertex);
    Polygon!Point_20_12 get_polygon(Polygon!Point_20_12 p);
    void reset();
}

final class TriangleAssembler : PolygonAssembler {
    int index = 0;
    Vertex!Point_20_12[4] vertices;

    override bool submit_vertex(Vertex!Point_20_12 vertex) {
        vertices[index] = vertex;
        index++;

        if (index > 2) {
            index = 0;
            return true;
        }

        return false;
    }

    Polygon!Point_20_12 get_polygon(Polygon!Point_20_12 p) {
        p.vertices[0..3] = vertices[0..3];
        p.num_vertices = 3;
        return p;
    }

    void reset() {
        index = 0;
    }
}

final class QuadAssembler : PolygonAssembler {
    int index = 0;
    Vertex!Point_20_12[4] vertices;

    override bool submit_vertex(Vertex!Point_20_12 vertex) {
        bool new_quad_created = index >= 3;

        vertices[index] = vertex;
        index++;

        if (index >= 4) {
            index = 0;
        }

        return new_quad_created;
    }

    Polygon!Point_20_12 get_polygon(Polygon!Point_20_12 p) {
        p.vertices[0..4] = vertices[0..4];
        p.num_vertices = 4;
        return p;
    }

    void reset() {
        index = 0;
    }
}

final class TriangleStripsAssembler : PolygonAssembler {
    int index = 0;
    Vertex!Point_20_12[4] vertices;

    override bool submit_vertex(Vertex!Point_20_12 vertex) {
        vertices[index] = vertex;
        index++;

        return index >= 3;
    }

    Polygon!Point_20_12 get_polygon(Polygon!Point_20_12 p) {
        p.vertices[0..3] = vertices[0..3];
        p.num_vertices = 3;
        
        vertices[0] = vertices[1];
        vertices[1] = vertices[2];
        index = 2;

        return p;
    }

    void reset() {
        index = 0;
    }
}

final class QuadStripsAssembler : PolygonAssembler {
    int index = 0;
    Vertex!Point_20_12[4] vertices;

    static immutable int[4] mapped_indices = [0, 1, 3, 2];

    override bool submit_vertex(Vertex!Point_20_12 vertex) {
        vertices[mapped_indices[index]] = vertex;
        index++;

        return index >= 4;
    }

    Polygon!Point_20_12 get_polygon(Polygon!Point_20_12 p) {
        p.vertices[0..4] = vertices[0..4];
        p.num_vertices = 4;

        index = 2;
        vertices[0] = vertices[3];
        vertices[1] = vertices[2];
        return p;
    }

    void reset() {
        index = 0;
    }
}