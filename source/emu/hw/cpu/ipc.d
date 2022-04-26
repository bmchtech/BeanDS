module emu.hw.cpu.ipc;

import emu;

import util;

__gshared IPC ipc7;
__gshared IPC ipc9;
final class IPC {
    final class Fifo {
        bool empty   = true;
        bool full    = false;

        int head = 0;
        int tail = 0;
        int size = 0;
        Word[16] data;
        Word last_popped = 0;

        IPC parent;

        this(IPC parent) {
            this.parent = parent;
        }
    
        Word pop() {
            full = false;

            if (!empty) {
                size--;
                tail++;
                tail &= 0xF;
                if (size == 0) {
                    empty = true;
                    if (parent.remote.fifo_empty_irq_enable) 
                        parent.remote.request_send_fifo_interrupt();
                }
                last_popped = data[tail];
            }

            return last_popped;
        }

        void push(Word value) {
            if (empty && parent.fifo_not_empty_irq_enable) 
                parent.request_receive_fifo_interrupt();

            empty = false;

            size++;
            head++;
            head &= 0xF;

            data[head] = value;

            if (size == 16) full = true;
        }

        void clear() {
            head = 0;
            tail = 0;
        }
    }

    InterruptManager interrupt;
    this(InterruptManager interrupt) {
        this.interrupt = interrupt;
        this.fifo = new Fifo(this);
    }

    Fifo fifo;
    Byte sync_data;
    bool sync_irq_enable;
    bool fifo_empty_irq_enable;
    bool fifo_not_empty_irq_enable;
    bool fifo_error;
    bool enabled;

    IPC remote;

    void set_remote(IPC ipc) {
        remote = ipc;
    }

    static void reset() {
        ipc7 = new IPC(interrupt7);
        ipc9 = new IPC(interrupt9);

        ipc7.set_remote(ipc9);
        ipc9.set_remote(ipc7);
    }

    Byte read_IPCSYNC(int target_byte) {
        final switch (target_byte) {
            case 0: return sync_data;
            case 1: return remote.sync_data;
            case 2: return Byte(0);
            case 3: return Byte(sync_irq_enable);
        }
    }

    void write_IPCSYNC(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0: return;
            case 1: 
                remote.sync_data = data[0..3];
                sync_irq_enable  = data[6] & 1;
                if (data[5]) request_sync_interrupt();
                return;
            case 2: return;
            case 3: return;
        }
    }

    Byte read_IPCFIFOCNT(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = Byte(remote.fifo.empty);
                result[1] = Byte(remote.fifo.full);
                result[2] = Byte(fifo_empty_irq_enable);
                break;
            case 1:
                result[0] = Byte(fifo.empty);
                result[1] = Byte(fifo.full);
                result[2] = Byte(fifo_not_empty_irq_enable);
                result[6] = Byte(fifo_error);
                result[7] = Byte(enabled);
                break;
        }

        return result;
    }

    void write_IPCFIFOCNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                fifo_empty_irq_enable = data[2];
                if (data[3]) { remote.fifo.clear(); if (this == ipc7) log_arm7("IPC7 fifo cleared"); else log_arm9("IPC9 fifo cleared"); }
                if (remote.fifo.empty && fifo_empty_irq_enable)
                    request_send_fifo_interrupt();
                return;
            case 1:
                fifo_not_empty_irq_enable =  data[2];
                fifo_error               &= !data[6];
                enabled                   =  data[7];
                if (!fifo.empty && fifo_not_empty_irq_enable)
                    request_receive_fifo_interrupt();
                return;
        }
    }

    void write_IPCFIFOSEND(T)(T data, int offset) {
        if (!enabled) return;

        data <<= offset * 8;
        
        if (remote.fifo.full) {
            fifo_error = true;
        } else {
            remote.fifo.push(Word(data));
        }
        // if (this == ipc7) log_arm7("ARM7 sending %x. %d / %d %x", data, remote.fifo.size, 16, enabled);
        // if (this == ipc9) log_arm9("ARM9 sending %x. %d / %d %x", data, remote.fifo.size, 16, enabled);
    }

    Word last_read_value;
    T read_IPCFIFORECV(T)(int offset) {
        if (!fifo.empty && enabled) {
            last_read_value = fifo.pop();
            // if (this == ipc7) log_arm7("ARM7 receiving %x. %d / %d", last_read_value, fifo.size, 16);
            // if (this == ipc9) log_arm9("ARM9 receiving %x. %d / %d", last_read_value, fifo.size, 16);
        } else {
            fifo_error = true;
        }

        return cast(T) (last_read_value >> (8 * offset));
    }

    void request_sync_interrupt() {
        if (remote.sync_irq_enable) {
            remote.interrupt.raise_interrupt(Interrupt.IPC_SYNC);
        }
    }

    void request_send_fifo_interrupt() {
        interrupt.raise_interrupt(Interrupt.IPC_SEND_FIFO_EMPTY);
    }

    void request_receive_fifo_interrupt() {
        interrupt.raise_interrupt(Interrupt.IPC_RECV_FIFO_NOT_EMPTY);
    }
}