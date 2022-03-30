module emu.hw.cpu.architecture;

import std.meta;

enum Architecture {
    v4T,
    v5TE
}

string generate_prettier_architecture_functions() {
    import std.format;
    import std.conv;
    import std.format;
    import std.traits;
    import std.uni;

    string mixed_in = "";
    
    foreach (architecture; EnumMembers!Architecture) {
        string architecture_name = to!string(architecture);

        mixed_in ~= "
            alias %s(T) = Alias!(T.architecture == Architecture.%s);
        ".format(architecture_name, architecture_name);
    }

    return mixed_in;
}

mixin(generate_prettier_architecture_functions());