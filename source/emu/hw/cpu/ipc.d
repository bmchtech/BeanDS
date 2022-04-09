module emu.hw.cpu.ipc;

import emu;

import util;

__gshared IPC ipc7;
__gshared IPC ipc9;
final class IPC {
    final class Fifo {
        bool empty   = true;
        bool full    = false;
        bool enabled = true;

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

            if (!empty && enabled) {
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

            if (enabled) {
                size++;
                head++;
                head &= 0xF;

                data[head] = value;

                if (size == 16) full = true;
            }
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
                result[7] = Byte(fifo.enabled);
                break;
        }

        return result;
    }

    void write_IPCFIFOCNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                fifo_empty_irq_enable = data[2];
                if (data[3]) remote.fifo.clear();
                if (remote.fifo.empty && fifo_empty_irq_enable)
                    request_send_fifo_interrupt();
                return;
            case 1:
                fifo_not_empty_irq_enable =  data[2];
                fifo_error               &= !data[6];
                fifo.enabled              =  data[7];
                if (!fifo.empty && fifo_empty_irq_enable)
                    request_receive_fifo_interrupt();
                return;
        }
    }

    Byte read_IPCFIFOSEND(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = remote.fifo.empty;
                result[1] = remote.fifo.full;
                result[2] = remote.fifo_empty_irq_enable;

                break;

            case 1:
                result[0] = fifo.empty;
                result[1] = fifo.full;
                result[2] = fifo_not_empty_irq_enable;
                result[6] = fifo_error;
                result[7] = fifo.enabled;
                break;
        }

        return result;
    }

    void write_IPCFIFOSEND(T)(T data) {
        if (remote.fifo.full) {
            fifo_error = true;
        } else {
            remote.fifo.push(Word(data));
        }
    }

    T read_IPCFIFORECV(T)() {
        if (fifo.empty) {
            fifo_error = true;
        }

        return cast(T) fifo.pop();
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