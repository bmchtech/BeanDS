module common.log;

enum LogSource {
    MEMORY
}

static immutable ulong logsource_padding = get_largest_logsource_length!();

static ulong get_largest_logsource_length()(){
    import std.algorithm;
    import std.conv;

    ulong largest_logsource_length = 0;
    foreach (source; LogSource.min .. LogSource.max) {
        largest_logsource_length = max(to!string(source).length, largest_logsource_length);
    }

    return largest_logsource_length;
}

// thanks https://github.com/dlang/phobos/blob/4239ed8ebd3525206453784908f5d37c82d338ee/std/outbuffer.d
void log(LogSource log_source, Char, A...)(scope const(Char)[] fmt, A args) {
    import std.format.write : formattedWrite;
    import std.conv;

    writef("[%s: ", timestamp, pad_string_right!(to!string(log_source), logsource_padding));
    writefln(fmt, args);
}

static string pad_string_right(string s, ulong pad)() {
    import std.array;

    static assert(s.length <= pad);
    return s ~ (replicate(" ", pad - s.length));
}

static string generate_prettier_logging_functions() {
    import std.conv;
    import std.format;
    import std.uni;

    string mixed_in = "";
    
    foreach (source; LogSource.min .. LogSource.max) {
        string source_name = to!string(source);

        mixed_in ~= "
            void log_%s(Char, A...)(scope const(Char)[] fmt, A args) {
                log(LogSource!%s, Char, A)(fmt, args);
            }
        ".format(source_name.toLower(), source_name);
    }

    return mixed_in;
}

mixin(
    generate_prettier_logging_functions()
);