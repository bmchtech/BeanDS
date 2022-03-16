module util.types;

import util;

union MemoryUnit(T) {
    T value;
    alias value this;

    this(S)(S value) {
        this.value = cast(T) value;
    }

    MemoryUnit!T opUnary(string s)() {
        return mixin(
            "MemoryUnit!T(" ~ s ~ "this.value)"
        );
    }

    MemoryUnit!T opBinary(string s)(MemoryUnit!T other) {
        return mixin(
            "MemoryUnit!T(this.value " ~ s ~ " other.value)"
        );
    }

    MemoryUnit!T opBinary(string s)(T other) {
        return mixin(
            "MemoryUnit!T(this.value " ~ s ~ " other)"
        );
    }

    MemoryUnit!T opSlice(size_t start, size_t end) {
        return MemoryUnit!T(this.value.bits(start, end));
    }

    bool opIndex(size_t index) {
        return this.value.bit(index) & 1;
    }

    T opCast(T)() {
        return cast(T) value;
    }

    MemoryUnit!T rotate_right(size_t shift) {
        return MemoryUnit!T(
            util.rotate_right(this.value, shift)
        );
    }

    size_t bitsize() {
        static if (is(T == uint))   return 32;
        static if (is(T == ushort)) return 16;
        static if (is(T == ubyte))  return 8;
    }

    void opSliceAssign(T value, size_t start, size_t end) {
        auto mask = create_mask(start, end);
        value &= mask;

        this.value &= ~(mask << start);
        this.value |=  value << start;
    }

    void opIndexAssign(T value, size_t index) {
        this.value &= ~(1     << index);
        this.value |=  (value << index);
    }

    void opAssign(S)(S value) {
        this.value = cast(T) value;
    }
}

void check_memory_unit(T)() {
    static assert (
        is(T == Word) ||
        is(T == Half) ||
        is(T == Byte)
    );
}

alias Word = MemoryUnit!uint;
alias Half = MemoryUnit!ushort;
alias Byte = MemoryUnit!ubyte;

alias u64 = ulong;
alias u32 = uint;
alias u16 = ushort;
alias u8  = ubyte;
alias s64 = long;
alias s32 = int;
alias s16 = short;
alias s8  = byte;
