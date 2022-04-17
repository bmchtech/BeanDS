module emu.debugger.cputrace;

import emu.hw.cpu;

import util;

struct CpuTraceState {
    InstructionSet instruction_set;
    Word           opcode;
    Word[16]       regs;
    Word           cpsr;
    Word           spsr;
}

CpuTraceState get_cpu_trace_state(ArmCPU cpu) {
    CpuTraceState cpu_trace_state;
    
    cpu_trace_state.instruction_set = cpu.get_instruction_set();
    cpu_trace_state.opcode          = cpu.get_pipeline_entry(0);
    cpu_trace_state.cpsr            = cpu.get_cpsr();
    cpu_trace_state.spsr            = cpu.get_spsr();

    for (int i = 0; i < 16; i++) {
        cpu_trace_state.regs[i] = cpu.get_reg(i);
    }

    return cpu_trace_state;
}

final class CpuTrace {
    ArmCPU cpu;
    RingBuffer!CpuTraceState ringbuffer;

    this(ArmCPU cpu, int length) {
        this.cpu        = cpu;
        this.ringbuffer = new RingBuffer!CpuTraceState(length);
    }

    void capture() {
        ringbuffer.add(get_cpu_trace_state(cpu));
    }

    void print_trace() {
        import std.stdio;
        import std.format;

        CpuTraceState[] trace = ringbuffer.get();
        for (int i = 0; i < trace.length; i++) {
            writef("[%04d] ", trace.length - i);
            
            if (trace[i].instruction_set == InstructionSet.THUMB) {
                write("THM ");
                write(format("    %04x || ", trace[i].opcode));
            } else {
                write("ARM ");
                write(format("%08x || ", trace[i].opcode));
            }

            for (int j = 0; j < 16; j++)
                write(format("%08x ", trace[i].regs[j]));

            write(format("| %08x ", trace[i].cpsr));
            write(format("| %08x", trace[i].spsr));
            writeln();
        }
    }
}