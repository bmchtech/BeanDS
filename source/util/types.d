module util.types;

struct Unit(T) {
    T value;
    alias value this;

    Unit!T opUnary(string s)() {
        return mixin(
            "Unit!T(" ~ s ~ "this)"
        );
    }

    Unit!T opBinary(string s)(Unit!T other) {
        return mixin(
            "Unit!T(this " ~ s ~ " other)"
        );
    }

    Unit!T opSlice(size_t start, size_t end) {
        auto mask = create_mask(start, end);
        return Unit!T((this.value >> start) & mask);
    }

    Unit!T opSlice(size_t index) {
        return Unit!T((this.value >> index) & 1);
    }
}

alias Word = Unit!uint;
alias Half = Unit!ushort;
alias Byte = Unit!ubyte;