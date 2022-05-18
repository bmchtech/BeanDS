module emu.hw.gpu.gpu3d.polygon;

import emu;
import util;

struct Vertex {
    Vec4 pos;
    int r;
    int g;
    int b;
    Vec4 texcoord;
}

struct Polygon {
    Vertex[4] vertices;

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
}

interface PolygonAssembler {
    bool submit_vertex(Vertex vertex);
    Vertex[4] get_vertices();
    void reset();
}

final class TriangleAssembler : PolygonAssembler {
    int index = 0;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        vertices[index] = vertex;
        index++;

        if (index > 2) {
            index = 0;
            return true;
        }

        return false;
    }

    Vertex[4] get_vertices() {
        return vertices;
    }

    void reset() {
        index = 0;
    }
}

final class QuadAssembler : PolygonAssembler {
    int index = 0;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        bool new_triangle_created = index >= 2;

        if (index < 3) {
            vertices[index] = vertex;
            index++;
        } else {
            vertices[1] = vertex;
            index = 0;
        }

        return new_triangle_created;
    }

    Vertex[4] get_vertices() {
        return vertices;
    }

    void reset() {
        index = 0;
    }
}

final class TriangleStripsAssembler : PolygonAssembler {
    int index = 0;
    int num_vertices;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        vertices[index] = vertex;

        index++;
        num_vertices++;
        if (index >= 3) index -= 3;

        return num_vertices >= 3;
    }

    Vertex[4] get_vertices() {
        return vertices;
    }

    void reset() {
        index = 0;
        num_vertices = 0;
    }
}

final class QuadStripsAssembler : PolygonAssembler {
    int index = 0;
    int num_vertices;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        vertices[index] = vertex;

        index++;
        num_vertices++;
        if (index >= 3) index -= 3;

        return num_vertices >= 3;
    }

    Vertex[4] get_vertices() {
        return vertices;
    }

    void reset() {
        index = 0;
        num_vertices = 0;
    }
}