module core.hw.cpu.ipc;

import core;

import util;

enum IPCSource {
    ARM7,
    ARM9
}

__gshared IPC ipc;
final class IPC {
    struct Fifo {
        bool empty   = true;
        bool full    = false;
        bool enabled = true;

        int index = 0;
        Word[16] data;
    
        Word pop() {
            full = false;

            if (enabled) {
                index--;
                if (index == 0) empty = true;
            }

            return data[index];
        }

        void push(Word value) {
            empty = false;

            if (enabled) {
                data[index] = value;

                index++;
                if (index == 16) full = true;
            }
        }

        void clear() {
            index = 0;
        }
    }

    struct State {
        Fifo fifo;
        Byte sync_data;
        bool sync_irq_enable;
        bool fifo_empty_irq_enable;
        bool fifo_full_irq_enable;
        bool fifo_error;
    }

    State* ipc7;
    State* ipc9;

    State* get_remote_state(IPCSource ipc_source) {
        final switch (ipc_source) {
            case IPCSource.ARM7: return ipc9;
            case IPCSource.ARM9: return ipc7;
        }
    }

    State* get_local_state(IPCSource ipc_source) {
        final switch (ipc_source) {
            case IPCSource.ARM7: return ipc7;
            case IPCSource.ARM9: return ipc9;
        }
    }
    
    this() {
        ipc = this;
    }

    Byte read_IPCSYNC(int target_byte, IPCSource ipc_source) {
        final switch (target_byte) {
            case 0: return get_local_state (ipc_source).sync_data;
            case 1: return get_remote_state(ipc_source).sync_data;
            case 2: return Byte(0);
            case 3: return get_local_state (ipc_source).sync_irq_enable;
        }
    }

    void write_IPCSYNC(int target_byte, Byte data, IPCSource ipc_source) {
        final switch (target_byte) {
            case 0: return;
            case 1: 
                get_remote_state(ipc_source).sync_data       = data[0..3];
                get_local_state (ipc_source).sync_irq_enable = data[6] & 1;
                if (data[5]) request_interrupt_from_source(ipc_source);
                return;
            case 2: return;
            case 3: return;
        }
    }

    Byte read_IPCFIFOCNT(int target_byte, IPCSource ipc_source) {
        return Byte(0);
    }

    void write_IPCFIFOCNT(int target_byte, Byte data, IPCSource ipc_source) {
        final switch (target_byte) {
            case 0:
                get_remote_state(ipc_source).fifo_empty_irq_enable = data[2];
                if (data[3]) get_remote_state(ipc_source).clear();
                return;
            case 1:
                get_local_state(ipc_source).fifo_full_irq_enable =  data[2];
                get_local_state(ipc_source).fifo_error          &= ~data[6];
                get_local_state(ipc_source).fifo.enabled         =  data[7];
                return;
        }
    }

    Byte read_IPCFIFOSEND(int target_byte, IPCSource ipc_source) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = get_remote_state(ipc_source).empty;
                result[1] = get_remote_state(ipc_source).full;
                result[2] = get_remote_state(ipc_source).fifo_empty_irq_enable;
                break;

            case 1:
                result[0] = get_local_state(ipc_source).empty;
                result[1] = get_local_state(ipc_source).full;
                result[2] = get_local_state(ipc_source).fifo_full_irq_enable;
                result[6] = get_local_state(ipc_source).fifo_error;
                result[7] = get_local_state(ipc_source).enabled;
                break;
        }

        return result;
    }

    void write_IPCFIFOSEND(T)(int target_byte, T data, IPCSource ipc_source) {
        if (get_remote_state(ipc_source).full) {
            get_local_state(ipc_source).error = true;
        } else {
            get_remote_state(ipc_source).push(data);
        }
    }

    Byte read_IPCFIFORECV(int target_byte, IPCSource ipc_source) {
        if (get_local_state(ipc_source).empty) {
            get_local_state(ipc_source).error = true;
            return get_local_state(ipc_source).pop();
        } else {
            return get_local_state(ipc_source).pop();
        }
    }

    void write_IPCFIFORECV(int target_byte, Byte data, IPCSource ipc_source) {
        
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