module core.hw.memory.mmio.mmio7;

import core.hw;

import util;

__gshared MMIO7 mmio7;
final class MMIO7 {
    enum IPCSYNC       = 0x4000180; //  2    R/W   IPC Synchronize Register
    enum IPCFIFOCNT    = 0x4000184; //  2    R/W   IPC Fifo Control Register
    enum IPCFIFOSEND   = 0x4000188; //  4      W   IPC Send Fifo 
    enum IPCFIFORECV   = 0x4100000; //  4    R     IPC Receive Fifo 

    enum IME           = 0x4000208; //  2    R/W   Interrupt Master Enable
    enum IE            = 0x4000210; //  4    R/W   Interrupt Enable
    enum IF            = 0x4000214; //  4    R/W   Interrupt Request Flags

    this() {
        mmio7 = this;
    }

    Byte read_byte(Word address) {
        switch (address) {
            case IPCSYNC     + 0: return ipc.read_IPCSYNC     (0, IPCSource.ARM7);
            case IPCSYNC     + 1: return ipc.read_IPCSYNC     (1, IPCSource.ARM7);
            case IPCSYNC     + 2: return ipc.read_IPCSYNC     (2, IPCSource.ARM7);
            case IPCSYNC     + 3: return ipc.read_IPCSYNC     (3, IPCSource.ARM7);
            // case IPCFIFOCNT  + 0: return ipc.read_IPCFIFOCNT  (0, IPCSource.ARM7);
            // case IPCFIFOCNT  + 1: return ipc.read_IPCFIFOCNT  (1, IPCSource.ARM7);
            // case IPCFIFOCNT  + 2: return ipc.read_IPCFIFOCNT  (2, IPCSource.ARM7);
            // case IPCFIFOCNT  + 3: return ipc.read_IPCFIFOCNT  (3, IPCSource.ARM7);
            // case IPCFIFORECV + 0: return ipc.read_IPCFIFORECV (0, IPCSource.ARM7);
            // case IPCFIFORECV + 1: return ipc.read_IPCFIFORECV (1, IPCSource.ARM7);
            // case IPCFIFORECV + 2: return ipc.read_IPCFIFORECV (2, IPCSource.ARM7);
            // case IPCFIFORECV + 3: return ipc.read_IPCFIFORECV (3, IPCSource.ARM7);

            case IME + 0: return interrupt7.read_IME (0); 
            case IME + 1: return interrupt7.read_IME (1);
            case IE  + 0: return interrupt7.read_IE  (0);
            case IE  + 1: return interrupt7.read_IE  (1);
            case IE  + 2: return interrupt7.read_IE  (2);
            case IE  + 3: return interrupt7.read_IE  (3);
            case IF  + 0: return interrupt7.read_IF  (0);
            case IF  + 1: return interrupt7.read_IF  (1);
            case IF  + 2: return interrupt7.read_IF  (2);
            case IF  + 3: return interrupt7.read_IF  (3);

            default: log_unimplemented("MMIO 7 register %x read from. This register does not exist.", address);
        }

        return Byte(0); // not possible
    }

    void write_byte(Word address, Byte data) {
        switch (address) {
            case IPCSYNC     + 0: ipc.write_IPCSYNC     (0, data, IPCSource.ARM7); break;
            case IPCSYNC     + 1: ipc.write_IPCSYNC     (1, data, IPCSource.ARM7); break;
            case IPCSYNC     + 2: ipc.write_IPCSYNC     (2, data, IPCSource.ARM7); break;
            case IPCSYNC     + 3: ipc.write_IPCSYNC     (3, data, IPCSource.ARM7); break;
            // case IPCFIFOCNT  + 0: ipc.write_IPCFIFOCNT  (0, data, IPCSource.ARM7); break;
            // case IPCFIFOCNT  + 1: ipc.write_IPCFIFOCNT  (1, data, IPCSource.ARM7); break;
            // case IPCFIFOCNT  + 2: ipc.write_IPCFIFOCNT  (2, data, IPCSource.ARM7); break;
            // case IPCFIFOCNT  + 3: ipc.write_IPCFIFOCNT  (3, data, IPCSource.ARM7); break;
            // case IPCFIFOSEND + 0: ipc.write_IPCFIFOSEND (0, data, IPCSource.ARM7); break;
            // case IPCFIFOSEND + 1: ipc.write_IPCFIFOSEND (1, data, IPCSource.ARM7); break;
            // case IPCFIFOSEND + 2: ipc.write_IPCFIFOSEND (2, data, IPCSource.ARM7); break;
            // case IPCFIFOSEND + 3: ipc.write_IPCFIFOSEND (3, data, IPCSource.ARM7); break;

            case IME + 0: interrupt7.write_IME (0, data); break;
            case IME + 1: interrupt7.write_IME (1, data); break;
            case IE  + 0: interrupt7.write_IE  (0, data); break;
            case IE  + 1: interrupt7.write_IE  (1, data); break;
            case IE  + 2: interrupt7.write_IE  (2, data); break;
            case IE  + 3: interrupt7.write_IE  (3, data); break;
            case IF  + 0: interrupt7.write_IF  (0, data); break;
            case IF  + 1: interrupt7.write_IF  (1, data); break;
            case IF  + 2: interrupt7.write_IF  (2, data); break;
            case IF  + 3: interrupt7.write_IF  (3, data); break;

            default: log_unimplemented("MMIO 7 register %x written to with value %x; This register does not exist.", address, data); break;
        }
    }

    T read(T)(Word address) {
        static if (is(T == Word)) {
            Word value = Word(0);
            value[0 .. 7] = read_byte(address + 0);
            value[8 ..15] = read_byte(address + 1); 
            value[16..23] = read_byte(address + 2); 
            value[24..31] = read_byte(address + 3);
            return value;  
        }

        static if (is(T == Half)) {
            Half value = Half(0);
            value[0.. 7] = read_byte(address + 0); 
            value[8..15] = read_byte(address + 1);
            return value;
        }

        static if (is(T == Byte)) {
            return read_byte(address);
        }
    }

    void write(T)(Word address, T value) {
        static if (is(T == Word)) {
            write_byte(address + 0, cast(Byte) value[0 .. 7]);
            write_byte(address + 1, cast(Byte) value[8 ..15]);
            write_byte(address + 2, cast(Byte) value[16..23]);
            write_byte(address + 3, cast(Byte) value[24..31]);
        }

        static if (is(T == Half)) {
            write_byte(address + 0, cast(Byte) value[0 .. 7]);
            write_byte(address + 1, cast(Byte) value[8 ..15]);
        }

        static if (is(T == Byte)) {
            write_byte(address, value);
        }
    }
}