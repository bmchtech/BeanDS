module emu.hw.gpu.pixel;

import util;

// TODO: does this ui-shared common struct really belong here?
struct Pixel {
    this(uint r, uint g, uint b) {
        this.r = r;
        this.g = g;
        this.b = b;
    }
    
    this(Half half) {
        this.b = half[10..14];
        this.g = half[5 .. 9];
        this.r = half[0 .. 4];
    }

    uint r;
    uint g;
    uint b;
}