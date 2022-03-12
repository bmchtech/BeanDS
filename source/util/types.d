module util.types;

import util;

struct MemoryUnit(T) {
    T value;
    alias value this;

    MemoryUnit!T opUnary(string s)() {
        return mixin(
            "MemoryUnit!T(" ~ s ~ "this)"
        );
    }

    MemoryUnit!T opBinary(string s)(MemoryUnit!T other) {
        return mixin(
            "MemoryUnit!T(this " ~ s ~ " other)"
        );
    }

    MemoryUnit!T opBinary(string s)(T other) {
        return mixin(
            "MemoryUnit!T(this " ~ s ~ " other)"
        );
    }

    MemoryUnit!T opSlice(size_t start, size_t end) {
        return MemoryUnit!T(this.value.bits(start, end));
    }

    MemoryUnit!T opSlice(size_t index) {
        return MemoryUnit!T(this.value.bit(index));
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
