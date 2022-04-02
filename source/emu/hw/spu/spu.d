module emu.hw.spu.spu;

import util;

__gshared SPU spu;
final class SPU {
    private this() {

    }

    static void reset() {
        spu = new SPU();
    }

    struct SoundChannel {
        int volume_mul;
        int volume_div;
        bool hold;
        int panning;
        int wave_duty;
        int repeat_mode;
        int format;
        bool enabled;
    }

    SoundChannel[16] sound_channels;

    // Byte read_SOUNDxCNT(int target_byte, int x) {
    //     Byte result = 0;
    //     auto c = sound_channels[x];
        
    //     final switch (target_byte) {
    //          case 0:
    //             result[0..6] = c.volume_mul;
    //             break;
    //         case 1:
    //             result[0..1] = c.volume_div;
    //             break;
    //         case 2:
    //             result[0..6] = c.panning;
    //             break;
    //         case 3:
    //             result[0..2] = c.wave_duty;
    //             result[3..4] = c.repeat_mode;
    //             result[5..6] = c.format;
    //             result[7]    = c.enabled;
    //     }

    //     return result;
    // }
    
    
    void sample() {

    }
}