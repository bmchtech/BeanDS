module core.hw.memory.mmio.mmio9;

import core.hw;

import util;

__gshared MMIO9 mmio9;
final class MMIO9 {

    // IO Registers
    //   NAME            ADDRESS       SIZE  R/W   DESCRIPTION
    enum DISPCNT       = 0x4000000; //  4    R/W   Engine A LCD Control
    enum DISPSTAT      = 0x4000004; //  4    R/W   General LCD Status

    enum DMA0SAD       = 0x40000B0; //  4      W   DMA 0 Source Address
    enum DMA0DAD       = 0x40000B4; //  4      W   DMA 0 Destination Address
    enum DMA0CNT_L     = 0x40000B8; //  2      W   DMA 0 Word Count
    enum DMA0CNT_H     = 0x40000BA; //  2    R/W   DMA 0 Control
    enum DMA1SAD       = 0x40000BC; //  4      W   DMA 1 Source Address
    enum DMA1DAD       = 0x40000C0; //  4      W   DMA 1 Destination Address
    enum DMA1CNT_L     = 0x40000C4; //  2      W   DMA 1 Word Count
    enum DMA1CNT_H     = 0x40000C6; //  2    R/W   DMA 1 Control
    enum DMA2SAD       = 0x40000C8; //  4      W   DMA 2 Source Address
    enum DMA2DAD       = 0x40000CC; //  4      W   DMA 2 Destination Address
    enum DMA2CNT_L     = 0x40000D0; //  2      W   DMA 2 Word Count
    enum DMA2CNT_H     = 0x40000D2; //  2    R/W   DMA 2 Control
    enum DMA3SAD       = 0x40000D4; //  4      W   DMA 3 Source Address
    enum DMA3DAD       = 0x40000D8; //  4      W   DMA 3 Destination Address
    enum DMA3CNT_L     = 0x40000DC; //  2      W   DMA 3 Word Count
    enum DMA3CNT_H     = 0x40000DE; //  2    R/W   DMA 3 Control

    enum KEYINPUT      = 0x4000130; //  2    R     Key Status

    enum IPCSYNC       = 0x4000180; //  2    R/W   IPC Synchronize Register
    enum IPCFIFOCNT    = 0x4000184; //  2    R/W   IPC Fifo Control Register
    enum IPCFIFOSEND   = 0x4000188; //  4      W   IPC Send Fifo 
    enum IPCFIFORECV   = 0x4100000; //  4    R     IPC Receive Fifo 

    enum VRAMCNT       = 0x4000240; //  1x9    W   VRAM Bank Control 

    this() {
        mmio9 = this;
    }

    Byte read_byte(Word address) {
        switch (address) {
            case DISPCNT     + 0: return gpu_engine_a.read_DISPCNT(0);
            case DISPCNT     + 1: return gpu_engine_a.read_DISPCNT(1);
            case DISPCNT     + 2: return gpu_engine_a.read_DISPCNT(2);
            case DISPCNT     + 3: return gpu_engine_a.read_DISPCNT(3);
            case DISPSTAT    + 0: return gpu.read_DISPSTAT        (0);
            case DISPSTAT    + 1: return gpu.read_DISPSTAT        (1);
            case DISPSTAT    + 2: return gpu.read_DISPSTAT        (2);
            case DISPSTAT    + 3: return gpu.read_DISPSTAT        (3);

            case DMA0SAD     + 0: return dma9.read_DMAXSAD        (0, 0);
            case DMA0SAD     + 1: return dma9.read_DMAXSAD        (1, 0);
            case DMA0SAD     + 2: return dma9.read_DMAXSAD        (2, 0);
            case DMA0SAD     + 3: return dma9.read_DMAXSAD        (3, 0);
            case DMA0DAD     + 0: return dma9.read_DMAXDAD        (0, 0);
            case DMA0DAD     + 1: return dma9.read_DMAXDAD        (1, 0);
            case DMA0DAD     + 2: return dma9.read_DMAXDAD        (2, 0);
            case DMA0DAD     + 3: return dma9.read_DMAXDAD        (3, 0);
            case DMA0CNT_L   + 0: return dma9.read_DMAXCNT_L      (0, 0);
            case DMA0CNT_L   + 1: return dma9.read_DMAXCNT_L      (1, 0);
            case DMA0CNT_H   + 0: return dma9.read_DMAXCNT_H      (0, 0);
            case DMA0CNT_H   + 1: return dma9.read_DMAXCNT_H      (1, 0);
            case DMA1SAD     + 0: return dma9.read_DMAXSAD        (0, 1);
            case DMA1SAD     + 1: return dma9.read_DMAXSAD        (1, 1);
            case DMA1SAD     + 2: return dma9.read_DMAXSAD        (2, 1);
            case DMA1SAD     + 3: return dma9.read_DMAXSAD        (3, 1);
            case DMA1DAD     + 0: return dma9.read_DMAXDAD        (0, 1);
            case DMA1DAD     + 1: return dma9.read_DMAXDAD        (1, 1);
            case DMA1DAD     + 2: return dma9.read_DMAXDAD        (2, 1);
            case DMA1DAD     + 3: return dma9.read_DMAXDAD        (3, 1);
            case DMA1CNT_L   + 0: return dma9.read_DMAXCNT_L      (0, 1);
            case DMA1CNT_L   + 1: return dma9.read_DMAXCNT_L      (1, 1);
            case DMA1CNT_H   + 0: return dma9.read_DMAXCNT_H      (0, 1);
            case DMA1CNT_H   + 1: return dma9.read_DMAXCNT_H      (1, 1);
            case DMA2SAD     + 0: return dma9.read_DMAXSAD        (0, 2);
            case DMA2SAD     + 1: return dma9.read_DMAXSAD        (1, 2);
            case DMA2SAD     + 2: return dma9.read_DMAXSAD        (2, 2);
            case DMA2SAD     + 3: return dma9.read_DMAXSAD        (3, 2);
            case DMA2DAD     + 0: return dma9.read_DMAXDAD        (0, 2);
            case DMA2DAD     + 1: return dma9.read_DMAXDAD        (1, 2);
            case DMA2DAD     + 2: return dma9.read_DMAXDAD        (2, 2);
            case DMA2DAD     + 3: return dma9.read_DMAXDAD        (3, 2);
            case DMA2CNT_L   + 0: return dma9.read_DMAXCNT_L      (0, 2);
            case DMA2CNT_L   + 1: return dma9.read_DMAXCNT_L      (1, 2);
            case DMA2CNT_H   + 0: return dma9.read_DMAXCNT_H      (0, 2);
            case DMA2CNT_H   + 1: return dma9.read_DMAXCNT_H      (1, 2);
            case DMA3SAD     + 0: return dma9.read_DMAXSAD        (0, 3);
            case DMA3SAD     + 1: return dma9.read_DMAXSAD        (1, 3);
            case DMA3SAD     + 2: return dma9.read_DMAXSAD        (2, 3);
            case DMA3SAD     + 3: return dma9.read_DMAXSAD        (3, 3);
            case DMA3DAD     + 0: return dma9.read_DMAXDAD        (0, 3);
            case DMA3DAD     + 1: return dma9.read_DMAXDAD        (1, 3);
            case DMA3DAD     + 2: return dma9.read_DMAXDAD        (2, 3);
            case DMA3DAD     + 3: return dma9.read_DMAXDAD        (3, 3);
            case DMA3CNT_L   + 0: return dma9.read_DMAXCNT_L      (0, 3);
            case DMA3CNT_L   + 1: return dma9.read_DMAXCNT_L      (1, 3);
            case DMA3CNT_H   + 0: return dma9.read_DMAXCNT_H      (0, 3);
            case DMA3CNT_H   + 1: return dma9.read_DMAXCNT_H      (1, 3);

            case IPCSYNC     + 0: return ipc.read_IPCSYNC         (0, IPCSource.ARM9);
            case IPCSYNC     + 1: return ipc.read_IPCSYNC         (1, IPCSource.ARM9);
            case IPCSYNC     + 2: return ipc.read_IPCSYNC         (2, IPCSource.ARM9);
            case IPCSYNC     + 3: return ipc.read_IPCSYNC         (3, IPCSource.ARM9);
            // case IPCFIFOCNT  + 0: return ipc.read_IPCFIFOCNT      (0, IPCSource.ARM9);
            // case IPCFIFOCNT  + 1: return ipc.read_IPCFIFOCNT      (1, IPCSource.ARM9);
            // case IPCFIFOCNT  + 2: return ipc.read_IPCFIFOCNT      (2, IPCSource.ARM9);
            // case IPCFIFOCNT  + 3: return ipc.read_IPCFIFOCNT      (3, IPCSource.ARM9);
            // case IPCFIFORECV + 0: return ipc.read_IPCFIFORECV     (0, IPCSource.ARM9);
            // case IPCFIFORECV + 1: return ipc.read_IPCFIFORECV     (1, IPCSource.ARM9);
            // case IPCFIFORECV + 2: return ipc.read_IPCFIFORECV     (2, IPCSource.ARM9);
            // case IPCFIFORECV + 3: return ipc.read_IPCFIFORECV     (3, IPCSource.ARM9);

            case KEYINPUT    + 0: return input.read_KEYINPUT      (0);
            case KEYINPUT    + 1: return input.read_KEYINPUT      (1);
            case 0x4000014: error_unimplemented("sussy");

            default: log_unimplemented("MMIO 9 register %x read from. This register does not exist.", address);
        }

        return Byte(0); // not possible
    }

    void write_byte(Word address, Byte data) {
        switch (address) {
            case DISPCNT     + 0: gpu_engine_a.write_DISPCNT (0, data);    break;
            case DISPCNT     + 1: gpu_engine_a.write_DISPCNT (1, data);    break;
            case DISPCNT     + 2: gpu_engine_a.write_DISPCNT (2, data);    break;
            case DISPCNT     + 3: gpu_engine_a.write_DISPCNT (3, data);    break;
            case DISPSTAT    + 0: gpu.write_DISPSTAT         (0, data);    break;
            case DISPSTAT    + 1: gpu.write_DISPSTAT         (1, data);    break;
            case DISPSTAT    + 2: gpu.write_DISPSTAT         (2, data);    break;
            case DISPSTAT    + 3: gpu.write_DISPSTAT         (3, data);    break;

            case DMA0SAD     + 0: dma9.write_DMAXSAD         (0, data, 0); break;
            case DMA0SAD     + 1: dma9.write_DMAXSAD         (1, data, 0); break;
            case DMA0SAD     + 2: dma9.write_DMAXSAD         (2, data, 0); break;
            case DMA0SAD     + 3: dma9.write_DMAXSAD         (3, data, 0); break;
            case DMA0DAD     + 0: dma9.write_DMAXDAD         (0, data, 0); break;
            case DMA0DAD     + 1: dma9.write_DMAXDAD         (1, data, 0); break;
            case DMA0DAD     + 2: dma9.write_DMAXDAD         (2, data, 0); break;
            case DMA0DAD     + 3: dma9.write_DMAXDAD         (3, data, 0); break;
            case DMA0CNT_L   + 0: dma9.write_DMAXCNT_L       (0, data, 0); break;
            case DMA0CNT_L   + 1: dma9.write_DMAXCNT_L       (1, data, 0); break;
            case DMA0CNT_H   + 0: dma9.write_DMAXCNT_H       (0, data, 0); break;
            case DMA0CNT_H   + 1: dma9.write_DMAXCNT_H       (1, data, 0); break;
            case DMA1SAD     + 0: dma9.write_DMAXSAD         (0, data, 1); break;
            case DMA1SAD     + 1: dma9.write_DMAXSAD         (1, data, 1); break;
            case DMA1SAD     + 2: dma9.write_DMAXSAD         (2, data, 1); break;
            case DMA1SAD     + 3: dma9.write_DMAXSAD         (3, data, 1); break;
            case DMA1DAD     + 0: dma9.write_DMAXDAD         (0, data, 1); break;
            case DMA1DAD     + 1: dma9.write_DMAXDAD         (1, data, 1); break;
            case DMA1DAD     + 2: dma9.write_DMAXDAD         (2, data, 1); break;
            case DMA1DAD     + 3: dma9.write_DMAXDAD         (3, data, 1); break;
            case DMA1CNT_L   + 0: dma9.write_DMAXCNT_L       (0, data, 1); break;
            case DMA1CNT_L   + 1: dma9.write_DMAXCNT_L       (1, data, 1); break;
            case DMA1CNT_H   + 0: dma9.write_DMAXCNT_H       (0, data, 1); break;
            case DMA1CNT_H   + 1: dma9.write_DMAXCNT_H       (1, data, 1); break;
            case DMA2SAD     + 0: dma9.write_DMAXSAD         (0, data, 2); break;
            case DMA2SAD     + 1: dma9.write_DMAXSAD         (1, data, 2); break;
            case DMA2SAD     + 2: dma9.write_DMAXSAD         (2, data, 2); break;
            case DMA2SAD     + 3: dma9.write_DMAXSAD         (3, data, 2); break;
            case DMA2DAD     + 0: dma9.write_DMAXDAD         (0, data, 2); break;
            case DMA2DAD     + 1: dma9.write_DMAXDAD         (1, data, 2); break;
            case DMA2DAD     + 2: dma9.write_DMAXDAD         (2, data, 2); break;
            case DMA2DAD     + 3: dma9.write_DMAXDAD         (3, data, 2); break;
            case DMA2CNT_L   + 0: dma9.write_DMAXCNT_L       (0, data, 2); break;
            case DMA2CNT_L   + 1: dma9.write_DMAXCNT_L       (1, data, 2); break;
            case DMA2CNT_H   + 0: dma9.write_DMAXCNT_H       (0, data, 2); break;
            case DMA2CNT_H   + 1: dma9.write_DMAXCNT_H       (1, data, 2); break;
            case DMA3SAD     + 0: dma9.write_DMAXSAD         (0, data, 3); break;
            case DMA3SAD     + 1: dma9.write_DMAXSAD         (1, data, 3); break;
            case DMA3SAD     + 2: dma9.write_DMAXSAD         (2, data, 3); break;
            case DMA3SAD     + 3: dma9.write_DMAXSAD         (3, data, 3); break;
            case DMA3DAD     + 0: dma9.write_DMAXDAD         (0, data, 3); break;
            case DMA3DAD     + 1: dma9.write_DMAXDAD         (1, data, 3); break;
            case DMA3DAD     + 2: dma9.write_DMAXDAD         (2, data, 3); break;
            case DMA3DAD     + 3: dma9.write_DMAXDAD         (3, data, 3); break;
            case DMA3CNT_L   + 0: dma9.write_DMAXCNT_L       (0, data, 3); break;
            case DMA3CNT_L   + 1: dma9.write_DMAXCNT_L       (1, data, 3); break;
            case DMA3CNT_H   + 0: dma9.write_DMAXCNT_H       (0, data, 3); break;
            case DMA3CNT_H   + 1: dma9.write_DMAXCNT_H       (1, data, 3); break;

            case IPCSYNC     + 0: ipc.write_IPCSYNC          (0, data, IPCSource.ARM9); break;
            case IPCSYNC     + 1: ipc.write_IPCSYNC          (1, data, IPCSource.ARM9); break;
            case IPCSYNC     + 2: ipc.write_IPCSYNC          (2, data, IPCSource.ARM9); break;
            case IPCSYNC     + 3: ipc.write_IPCSYNC          (3, data, IPCSource.ARM9); break;
            // case IPCFIFOCNT  + 0: ipc.write_IPCFIFOCNT       (0, data, IPCSource.ARM9);
            // case IPCFIFOCNT  + 1: ipc.write_IPCFIFOCNT       (1, data, IPCSource.ARM9);
            // case IPCFIFOCNT  + 2: ipc.write_IPCFIFOCNT       (2, data, IPCSource.ARM9);
            // case IPCFIFOCNT  + 3: ipc.write_IPCFIFOCNT       (3, data, IPCSource.ARM9);
            // case IPCFIFOSEND + 0: ipc.write_IPCFIFOSEND      (0, data, IPCSource.ARM9);
            // case IPCFIFOSEND + 1: ipc.write_IPCFIFOSEND      (1, data, IPCSource.ARM9);
            // case IPCFIFOSEND + 2: ipc.write_IPCFIFOSEND      (2, data, IPCSource.ARM9);
            // case IPCFIFOSEND + 3: ipc.write_IPCFIFOSEND      (3, data, IPCSource.ARM9);

            case VRAMCNT     + 0: vram.write_VRAMCNT         (0, data); break;
            case VRAMCNT     + 1: vram.write_VRAMCNT         (1, data); break;
            case VRAMCNT     + 2: vram.write_VRAMCNT         (2, data); break;
            case VRAMCNT     + 3: vram.write_VRAMCNT         (3, data); break;
            case VRAMCNT     + 4: vram.write_VRAMCNT         (4, data); break;
            case VRAMCNT     + 5: vram.write_VRAMCNT         (5, data); break;
            case VRAMCNT     + 6: vram.write_VRAMCNT         (6, data); break;
            // TODO: wtf is this hole?
            case VRAMCNT     + 8: vram.write_VRAMCNT         (8, data); break;
            case VRAMCNT     + 9: vram.write_VRAMCNT         (9, data); break;

            default: log_unimplemented("MMIO 9 register %x written to with value %x; This register does not exist.", address, data); break;
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