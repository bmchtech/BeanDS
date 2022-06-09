module util.better_assert;

import std.format;
import std.stdio;

void assert_equal(T1, T2)(T1 left, T2 right, string format_specifier) {
    assert(left == right, "%s was not equal to %s".format(format_specifier, format_specifier).format(left, right));
}