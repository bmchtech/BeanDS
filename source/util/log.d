module util.log;

import emu;

private __gshared NDS nds;

enum LogSource {
    MEM7,
    MEM9,
    UNIMPLEMENTED,
    ARM7,
    ARM9,
    DMA7,
    DMA9,
    NDS,
    ENGINE_A,
    ENGINE_B,
    DIVISION,
    INTERRUPT,
    COPROCESSOR,
    TCM,
    VRAM,
    WRAM,
    PRAM,   
    TIMERS,
    PPU,
    SPU,
    IPC,
    CART,
    SPI,
    TOUCHSCREEN,
    AUXSPI,
    EEPROM,
    MAIN_MEMORY,
    FIRMWARE,
    GPU3D,
    RTC,
    POWERMAN,
    
    IFT,
    FUNCTION
}

static immutable ulong logsource_padding = get_largest_logsource_length!();

static ulong get_largest_logsource_length()(){
    import std.algorithm;
    import std.conv;
    import std.traits;

    ulong largest_logsource_length = 0;
    foreach (source; EnumMembers!LogSource) {
        largest_logsource_length = max(to!string(source).length, largest_logsource_length);
    }

    return largest_logsource_length;
}

// thanks https://github.com/dlang/phobos/blob/4239ed8ebd3525206453784908f5d37c82d338ee/std/outbuffer.d
private void log(LogSource log_source, bool fatal, Char, A...)(scope const(Char)[] fmt, A args) {
    import core.stdc.stdlib;
    import core.stdc.stdio;
    import core.runtime;

    import std.conv;
    import std.format.write : formattedWrite;
    import std.stdio : writef, writefln;
    
    version (silent) {
        return;
    } else

    version (quiet) {
        if (!fatal) return;
    } else

    {
        if (fatal) {
            writefln("===== ARM7 TRACE =====");
            arm7.cpu_trace.print_trace();
            writefln("===== ARM9 TRACE =====");
            arm9.cpu_trace.print_trace();
        }

        ulong timestamp = scheduler.get_current_time_relative_to_cpu();
        writef("%016x [%s] : ", timestamp, pad_string_right!(to!string(log_source), logsource_padding));
        writefln(fmt, args);

        if (fatal) {
            dump(wram.arm7_only_wram, "arm7_wram.dump");
            dump(wram.shared_bank_1, "wram_bank1.dump");
            dump(wram.shared_bank_2, "wram_bank2.dump");
            dump(main_memory.data, "main_memory.dump");

            auto trace = defaultTraceHandler(null);
            foreach (line; trace) {
                printf("%.*s\n", cast(int) line.length, line.ptr);
            }

            exit(-1);
        }
    }
}
 
private void connect_nds(NDS nds_) {
    nds = nds_;
}

static string pad_string_right(string s, ulong pad)() {
    import std.array;

    static assert(s.length <= pad);
    return s ~ (replicate(" ", pad - s.length));
}

static string generate_prettier_logging_functions() {
    import std.conv;
    import std.format;
    import std.traits;
    import std.uni;

    string mixed_in = "";
    
    foreach (source; EnumMembers!LogSource) {
        string source_name = to!string(source);

        mixed_in ~= "
            void log_%s(Char, A...)(scope const(Char)[] fmt, A args) {
                log!(LogSource.%s, false, Char, A)(fmt, args);
            }
        ".format(source_name.toLower(), source_name);

        mixed_in ~= "
            void error_%s(Char, A...)(scope const(Char)[] fmt, A args) {
                log!(LogSource.%s, true, Char, A)(fmt, args);
            }
        ".format(source_name.toLower(), source_name);
    }

    return mixed_in;
}

mixin(
    generate_prettier_logging_functions()
);