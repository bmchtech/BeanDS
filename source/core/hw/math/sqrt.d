module core.hw.math.sqrt;

import util;

__gshared SqrtController sqrt_controller;
public class SqrtController {
    bool mode;
    Word param_lo;
    Word param_hi;

    this() {
        sqrt_controller = this;
    }

    Byte read_SQRTCNT(int target_byte) {
        if (target_byte == 0) return Byte(mode);
        return Byte(0);
    }

    void write_SQRTCNT(int target_byte, Byte data) {
        if (target_byte == 0) mode = data[0];
    }

    Byte read_SQRT_PARAM(int target_byte) {
        final switch (target_byte) {
            case 0: return Byte(param_lo[0 .. 7]);
            case 1: return Byte(param_lo[8 ..15]);
            case 2: return Byte(param_lo[16..23]);
            case 3: return Byte(param_lo[24..31]);
            case 4: return Byte(param_hi[0 .. 7]);
            case 5: return Byte(param_hi[8 ..15]);
            case 6: return Byte(param_hi[16..23]);
            case 7: return Byte(param_hi[24..31]);
        }
    }

    void write_SQRT_PARAM(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0: param_lo[0 .. 7] = data; break;
            case 1: param_lo[8 ..15] = data; break;
            case 2: param_lo[16..23] = data; break;
            case 3: param_lo[24..31] = data; break;
            case 4: param_hi[0 .. 7] = data; break;
            case 5: param_hi[8 ..15] = data; break;
            case 6: param_hi[16..23] = data; break;
            case 7: param_hi[24..31] = data; break;
        }
    }

    Byte read_SQRT_RESULT(int target_byte) {
        Word result = calculate_result();
        return Byte(result[target_byte * 8 .. (target_byte + 1) * 8 - 1]);
    }

    Word calculate_result() {
        real operand = mode ? cast(u64) param_hi << 32 | cast(u64) param_lo : param_lo;
        real result = operand.sqrt().floor();
        while (result * result > operand) operand--;

        return Word(result);
    }
}