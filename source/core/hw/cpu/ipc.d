module core.hw.cpu.ipc;

import core;

import util;

enum IPCSource {
    ARM7,
    ARM9
}

__gshared IPC ipc;
final class IPC {
    Byte arm7_data = 0;
    Byte arm9_data = 0;
    bool arm7_irq_enable = false;
    bool arm9_irq_enable = false;
    
    this() {
        ipc = this;
    }

    Byte read_IPCSYNC(int target_byte, IPCSource ipc_source) {
        final switch (target_byte) {
            case 0: return get_input_data (ipc_source);
            case 1: return get_output_data(ipc_source);
            case 2: return Byte(0);
            case 3: return Byte(0);
        }
    }

    void write_IPCSYNC(int target_byte, Byte data, IPCSource ipc_source) {
        final switch (target_byte) {
            case 0: return;
            case 1: 
                set_input_data(ipc_source, data[0..3]);
                set_irq_enable(ipc_source, data[6] & 1);
                if (data[5]) request_interrupt_from_source(ipc_source);
                break;
            case 2: return;
            case 3: return;
        }
    }

    Byte get_input_data(IPCSource ipc_source) {
        final switch (ipc_source) {
            case IPCSource.ARM7: return arm7_data;
            case IPCSource.ARM9: return arm9_data;
        }
    }

    void set_input_data(IPCSource ipc_source, Byte data) {
        final switch (ipc_source) {
            case IPCSource.ARM7: arm9_data = data; break;
            case IPCSource.ARM9: arm7_data = data; break;
        }
    }

    void set_irq_enable(IPCSource ipc_source, bool value) {
        final switch (ipc_source) {
            case IPCSource.ARM7: arm7_irq_enable = value; break;
            case IPCSource.ARM9: arm9_irq_enable = value; break;
        }
    }

    void request_interrupt_from_source(IPCSource ipc_source) {
        final switch (ipc_source) {
            case IPCSource.ARM7: if (arm9_irq_enable) interrupt9.raise_interrupt(Interrupt.IPC_SYNC); break;
            case IPCSource.ARM9: if (arm7_irq_enable) interrupt7.raise_interrupt(Interrupt.IPC_SYNC); break;
        }
    }

    Byte get_output_data(IPCSource ipc_source) {
        final switch (ipc_source) {
            case IPCSource.ARM7: return arm9_data;
            case IPCSource.ARM9: return arm7_data;
        }
    }
}