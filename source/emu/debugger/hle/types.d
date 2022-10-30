module emu.debugger.hle.types;

import util;

// most structs taken from https://github.com/pret/pokediamond

// i use this struct to force the pointer to be 4 bytes
// this is needed because that's what the NDS uses.
struct Pointer(T) {
    u32 pointer;
}

static assert (Pointer!(u32).sizeof == 0x4);

struct OSContext {
    align(1):
    u32 cpsr;
    u32[13] r;
    u32 sp;
    u32 lr;
    u32 pc_plus4;
    u32 sp_svc;
    CPContext cp_context;
}

static assert (OSContext.sizeof == 0x64);

struct CPContext {
    align(1):
    u64 div_numer;
    u64 div_denom;
    u64 sqrt;
    u16 div_mode;
    u16 sqrt_mode;
}

static assert (CPContext.sizeof == 0x1C);

enum OSThreadState {
    OS_THREAD_STATE_WAITING = 0,
    OS_THREAD_STATE_READY = 1,
    OS_THREAD_STATE_TERMINATED = 2
}

static assert (OSThreadState.sizeof == 0x4);

struct OSThread {
    align(1):
    OSContext context;
    OSThreadState state;
    Pointer!OSThread next;
    u32 id;
    u32 priority;

    // the struct goes on, but the rest of the
    // fields are generally useless for debugging
}

static assert (OSThread.sizeof == 0x74);

struct OSThreadQueue {
    align(1):
    Pointer!OSThread head;
    Pointer!OSThread tail;
}

static assert (OSThreadQueue.sizeof == 0x8);