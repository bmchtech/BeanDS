module util.types;

import memoryunit;
import util;

struct FixedPoint(uint I, uint F) {
    int value;

    int repr() {
        return value & util.create_mask(0, I + F - 1);
    }

    this(uint value) {
        set_value(value);
    }

    FixedPoint!(I, F) opBinary(string s)(FixedPoint!(I, F) other)
        if (s == "+" || s == "-" || s == "*" || s == "/") {
        FixedPoint!(I, F) result;

        final switch (s) {
            case "+": result.set_value(this.value + other.value); break;
            case "-": result.set_value(this.value - other.value); break;
            case "*": result.set_value((this.value * other.value) >> F); break;
            case "/": result.set_value((this.value << F) / other.value); break;
        }

        return result; 
    }

    T opCast(T)()
        if (is(T == float)) {
        int sign = !util.bit(this.value, I + F - 1) * 2 - 1;
        auto unsigned_value = ((sign * sext_32(this.integral_part, I)) << F) | this.fractional_part; 
        return sign * (cast(float) (unsigned_value >> F)) + (cast(float) (unsigned_value & util.create_mask(0, F - 1))) / (1 << F);
    }

    FixedPoint!(I2, F2) convert(int I2, int F2)() {
        int integral_part = sext_32(this.integral_part, I2);
        int fractional_part = this.fractional_part;
        
        static if (F2 < F) {
            fractional_part >>= (F - F2);
        } else {
            fractional_part <<= (F2 - F);
        }

        int value = (integral_part << F2) | fractional_part;
        return FixedPoint!(I2, F2)(value);
    }

    void set_value(int value) {
        this.value = sext_32(value, I + F - 1);
    }

    int integral_part() {
        return value >> F;
    }

    int fractional_part() {
        return value & util.create_mask(0, F - 1);
    }
}

unittest {
    FixedPoint!(4, 8) fp1 = 0xF00;
    assert_equal(cast(float) fp1, -1.0f, "%f");
}

unittest {
    FixedPoint!(8, 4) fp1 = 0xFE0;
    FixedPoint!(8, 4) fp2 = 0x058;

    assert_equal(cast(float) fp1, -2.0f, "%f");
    assert_equal(cast(float) fp2, 5.5f, "%f");

    assert_equal(cast(float) (fp1 + fp2), 3.5f, "%f");
    assert_equal(cast(float) (fp1 - fp2), -7.5f, "%f");
    assert_equal(cast(float) (fp1 * fp2), -11.0f, "%f");
    assert_equal(cast(float) (fp2 / fp1), -2.75f, "%f");
}

unittest {
    FixedPoint!(4, 4) fp1 = 0xED; // -1.875
    assert_equal(cast(float) fp1, -1.1875f, "%f");

    auto fp2 = fp1.convert!(3, 3);
    assert_equal(cast(float) fp2, -1.25f, "%f"); // precision loss
    assert_equal(fp2.repr, 0x36, "%04x");

    auto fp3 = fp1.convert!(5, 5);
    assert_equal(cast(float) fp3, -1.1875f, "%f");
    assert_equal(fp3.repr, 0x3DA, "%04x");
}

void check_memory_unit(T)() {
    static assert (
        is(T == Word) ||
        is(T == Half) ||
        is(T == Byte)
    );
}

alias Word  = MemoryUnit!uint;
alias Half  = MemoryUnit!ushort;
alias Byte  = MemoryUnit!ubyte;

alias u64 = ulong;
alias u32 = uint;
alias u16 = ushort;
alias u8  = ubyte;
alias s64 = long;
alias s32 = int;
alias s16 = short;
alias s8  = byte;
