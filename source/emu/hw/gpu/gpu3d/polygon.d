module emu.hw.gpu.gpu3d.polygon;

import emu;
import util;

struct Vertex {
    Vec4 pos;
    int r;
    int g;
    int b;
}
struct Polygon {
    Vertex[4] vertices;
    int size; // 3 or 4
}

interface PolygonAssembler {
    bool submit_vertex(Vertex vertex);
    Polygon get_polygon();
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

    Polygon get_polygon() {
        return Polygon(vertices, 3);
    }
}