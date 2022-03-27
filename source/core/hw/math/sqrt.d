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
        bool hi = target_byte.bit(2);
        int offset = target_byte.bits(0, 1);
        
        if (hi) return param_hi.get_byte(offset);
        else    return param_lo.get_byte(offset);
    }

    void write_SQRT_PARAM(int target_byte, Byte data) {
        bool hi = target_byte.bit(2);
        int offset = target_byte.bits(0, 1);
        
        if (hi) param_hi.set_byte(offset, data);
        else    param_lo.set_byte(offset, data);
    }

    Byte read_SQRT_RESULT(int target_byte) {
        Word result = calculate_result();
        return Byte(result[target_byte * 8 .. (target_byte + 1) * 8 - 1]);
    }

    Word calculate_result() {
        import std.math;
        
        real operand = mode ? cast(u64) param_hi << 32 | cast(u64) param_lo : param_lo;
        real result = operand.sqrt().floor();
        while (result * result > operand) operand--;

        return Word(result);
    }
}