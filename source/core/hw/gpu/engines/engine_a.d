module core.hw.gpu.engines.engine_a;

import core.hw;

import util;

__gshared GPUEngineA gpu_engine_a;
final class GPUEngineA {

    this() {
        gpu_engine_a = this;
    }

    int bg_mode;
    void write_DISPCNT(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                bg_mode = value[0..2];
                break;

            case 1: break;

            case 2: break;

            case 3: break; 
        }    
    }

    Byte read_DISPCNT(int target_byte) {
        return Byte(0);
    }
}