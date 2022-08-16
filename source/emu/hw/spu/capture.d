module emu.hw.spu.capture;

import util;

__gshared SoundCapture sound_capture;

final class SoundCapture {
    struct Capture {
        int control;
        int selection;
        int repeat;
        int format;
        int start;

        int dad;
        int len;
    }

    Capture[2] capture;

    Byte read_SNDCAPxCNT(int target_byte, int x) {
        Byte result = 0;

        result[0] = capture[x].control;
        result[1] = capture[x].selection;
        result[2] = capture[x].repeat;
        result[3] = capture[x].format;
        result[7] = capture[x].start;

        return result;
    }

    void write_SNDCAPxCNT(int target_byte, Byte data, int x) {
        capture[x].control   = data[0];
        capture[x].selection = data[1];
        capture[x].repeat    = data[2];
        capture[x].format    = data[3];
        capture[x].start     = data[7];
    }

    Byte read_SNDCAPxDAD(int target_byte, int x) {
        return Byte(capture[x].dad);
    }

    void write_SNDCAPxDAD(int target_byte, Byte data, int x) {
        capture[x].dad = data;
        capture[x].len &= 0x7FFFFFF;
    }

    void write_SNDCAPxLEN(int target_byte, Byte data, int x) {
        capture[x].len = data;
        capture[x].len &= 0xFFFF;
    }
}