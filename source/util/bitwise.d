module util.bitwise;

import util;

import std.traits;

pragma(inline, true) {
    auto create_mask(size_t start, size_t end) {
        return (1 << (end - start + 1)) - 1;
    }

    T bits(T)(T value, size_t start, size_t end) {
        auto mask = create_mask(start, end);
        return (value >> start) & mask;
    }

    bool bit(T)(T value, size_t index) {
        return (value >> index) & 1;
    }

    pure T rotate_right(T)(T value, size_t shift) 
    if (isIntegral!T) {
        return cast(T) ((value >> shift) | (value << (T.sizeof * 8 - shift)));
    }

    s32 sext_32(T)(T value, u32 size) {
        auto negative = value[size - 1];
        s32 result = value;

        if (negative) result |= (((1 << (32 - size)) - 1) << size);
        return result;
    }

    s64 sext_64(u64 value, u64 size) {
        auto negative = (value >> (size - 1)) & 1;
        if (negative) value |= (((1UL << (64UL - size)) - 1UL) << size);
        return value;
    }

}