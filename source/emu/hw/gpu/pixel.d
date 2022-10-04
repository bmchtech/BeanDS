module emu.hw.gpu.pixel;

import util;

// TODO: does this ui-shared common struct really belong here?
struct Pixel {
    this(uint r, uint g, uint b) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = 31;
    }
    this(uint r, uint g, uint b, uint a) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
    
    this(Half half) {
        this.b = half[10..14] << 1;
        this.g = half[5 .. 9] << 1;
        this.r = half[0 .. 4] << 1;
        this.a = 31;
    }

    align(1):
    uint r;
    uint g;
    uint b;
    uint a;
}

static assert (Pixel.sizeof == 16);