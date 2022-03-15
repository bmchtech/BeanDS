module core.hw.memory.mmio.mmio9;

import core.hw.memory.dma;

import util;

final class MMIO9 {

    // IO Registers
    //   NAME            ADDRESS       SIZE  R/W   DESCRIPTION

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

    ubyte read(Word address) {
        switch (address) {
            case DMA0SAD     + 0: return dma9.read_DMAXSAD    (0, 0);
            case DMA0SAD     + 1: return dma9.read_DMAXSAD    (1, 0);
            case DMA0SAD     + 2: return dma9.read_DMAXSAD    (2, 0);
            case DMA0SAD     + 3: return dma9.read_DMAXSAD    (3, 0);
            case DMA0DAD     + 0: return dma9.read_DMAXDAD    (0, 0);
            case DMA0DAD     + 1: return dma9.read_DMAXDAD    (1, 0);
            case DMA0DAD     + 2: return dma9.read_DMAXDAD    (2, 0);
            case DMA0DAD     + 3: return dma9.read_DMAXDAD    (3, 0);
            case DMA0CNT_L   + 0: return dma9.read_DMAXCNT_L  (0, 0);
            case DMA0CNT_L   + 1: return dma9.read_DMAXCNT_L  (1, 0);
            case DMA0CNT_H   + 0: return dma9.read_DMAXCNT_H  (0, 0);
            case DMA0CNT_H   + 1: return dma9.read_DMAXCNT_H  (1, 0);
            case DMA1SAD     + 0: return dma9.read_DMAXSAD    (0, 1);
            case DMA1SAD     + 1: return dma9.read_DMAXSAD    (1, 1);
            case DMA1SAD     + 2: return dma9.read_DMAXSAD    (2, 1);
            case DMA1SAD     + 3: return dma9.read_DMAXSAD    (3, 1);
            case DMA1DAD     + 0: return dma9.read_DMAXDAD    (0, 1);
            case DMA1DAD     + 1: return dma9.read_DMAXDAD    (1, 1);
            case DMA1DAD     + 2: return dma9.read_DMAXDAD    (2, 1);
            case DMA1DAD     + 3: return dma9.read_DMAXDAD    (3, 1);
            case DMA1CNT_L   + 0: return dma9.read_DMAXCNT_L  (0, 1);
            case DMA1CNT_L   + 1: return dma9.read_DMAXCNT_L  (1, 1);
            case DMA1CNT_H   + 0: return dma9.read_DMAXCNT_H  (0, 1);
            case DMA1CNT_H   + 1: return dma9.read_DMAXCNT_H  (1, 1);
            case DMA2SAD     + 0: return dma9.read_DMAXSAD    (0, 2);
            case DMA2SAD     + 1: return dma9.read_DMAXSAD    (1, 2);
            case DMA2SAD     + 2: return dma9.read_DMAXSAD    (2, 2);
            case DMA2SAD     + 3: return dma9.read_DMAXSAD    (3, 2);
            case DMA2DAD     + 0: return dma9.read_DMAXDAD    (0, 2);
            case DMA2DAD     + 1: return dma9.read_DMAXDAD    (1, 2);
            case DMA2DAD     + 2: return dma9.read_DMAXDAD    (2, 2);
            case DMA2DAD     + 3: return dma9.read_DMAXDAD    (3, 2);
            case DMA2CNT_L   + 0: return dma9.read_DMAXCNT_L  (0, 2);
            case DMA2CNT_L   + 1: return dma9.read_DMAXCNT_L  (1, 2);
            case DMA2CNT_H   + 0: return dma9.read_DMAXCNT_H  (0, 2);
            case DMA2CNT_H   + 1: return dma9.read_DMAXCNT_H  (1, 2);
            case DMA3SAD     + 0: return dma9.read_DMAXSAD    (0, 3);
            case DMA3SAD     + 1: return dma9.read_DMAXSAD    (1, 3);
            case DMA3SAD     + 2: return dma9.read_DMAXSAD    (2, 3);
            case DMA3SAD     + 3: return dma9.read_DMAXSAD    (3, 3);
            case DMA3DAD     + 0: return dma9.read_DMAXDAD    (0, 3);
            case DMA3DAD     + 1: return dma9.read_DMAXDAD    (1, 3);
            case DMA3DAD     + 2: return dma9.read_DMAXDAD    (2, 3);
            case DMA3DAD     + 3: return dma9.read_DMAXDAD    (3, 3);
            case DMA3CNT_L   + 0: return dma9.read_DMAXCNT_L  (0, 3);
            case DMA3CNT_L   + 1: return dma9.read_DMAXCNT_L  (1, 3);
            case DMA3CNT_H   + 0: return dma9.read_DMAXCNT_H  (0, 3);
            case DMA3CNT_H   + 1: return dma9.read_DMAXCNT_H  (1, 3);

            default: error_unimplemented("MMIO 9 register %x read from. This register does not exist.", address);
        }

        return 0; // not possible
    }

    void write(Word address, Byte data) {
        switch (address) {
            case DMA0SAD     + 0: dma9.write_DMAXSAD    (0, data, 0); break;
            case DMA0SAD     + 1: dma9.write_DMAXSAD    (1, data, 0); break;
            case DMA0SAD     + 2: dma9.write_DMAXSAD    (2, data, 0); break;
            case DMA0SAD     + 3: dma9.write_DMAXSAD    (3, data, 0); break;
            case DMA0DAD     + 0: dma9.write_DMAXDAD    (0, data, 0); break;
            case DMA0DAD     + 1: dma9.write_DMAXDAD    (1, data, 0); break;
            case DMA0DAD     + 2: dma9.write_DMAXDAD    (2, data, 0); break;
            case DMA0DAD     + 3: dma9.write_DMAXDAD    (3, data, 0); break;
            case DMA0CNT_L   + 0: dma9.write_DMAXCNT_L  (0, data, 0); break;
            case DMA0CNT_L   + 1: dma9.write_DMAXCNT_L  (1, data, 0); break;
            case DMA0CNT_H   + 0: dma9.write_DMAXCNT_H  (0, data, 0); break;
            case DMA0CNT_H   + 1: dma9.write_DMAXCNT_H  (1, data, 0); break;
            case DMA1SAD     + 0: dma9.write_DMAXSAD    (0, data, 1); break;
            case DMA1SAD     + 1: dma9.write_DMAXSAD    (1, data, 1); break;
            case DMA1SAD     + 2: dma9.write_DMAXSAD    (2, data, 1); break;
            case DMA1SAD     + 3: dma9.write_DMAXSAD    (3, data, 1); break;
            case DMA1DAD     + 0: dma9.write_DMAXDAD    (0, data, 1); break;
            case DMA1DAD     + 1: dma9.write_DMAXDAD    (1, data, 1); break;
            case DMA1DAD     + 2: dma9.write_DMAXDAD    (2, data, 1); break;
            case DMA1DAD     + 3: dma9.write_DMAXDAD    (3, data, 1); break;
            case DMA1CNT_L   + 0: dma9.write_DMAXCNT_L  (0, data, 1); break;
            case DMA1CNT_L   + 1: dma9.write_DMAXCNT_L  (1, data, 1); break;
            case DMA1CNT_H   + 0: dma9.write_DMAXCNT_H  (0, data, 1); break;
            case DMA1CNT_H   + 1: dma9.write_DMAXCNT_H  (1, data, 1); break;
            case DMA2SAD     + 0: dma9.write_DMAXSAD    (0, data, 2); break;
            case DMA2SAD     + 1: dma9.write_DMAXSAD    (1, data, 2); break;
            case DMA2SAD     + 2: dma9.write_DMAXSAD    (2, data, 2); break;
            case DMA2SAD     + 3: dma9.write_DMAXSAD    (3, data, 2); break;
            case DMA2DAD     + 0: dma9.write_DMAXDAD    (0, data, 2); break;
            case DMA2DAD     + 1: dma9.write_DMAXDAD    (1, data, 2); break;
            case DMA2DAD     + 2: dma9.write_DMAXDAD    (2, data, 2); break;
            case DMA2DAD     + 3: dma9.write_DMAXDAD    (3, data, 2); break;
            case DMA2CNT_L   + 0: dma9.write_DMAXCNT_L  (0, data, 2); break;
            case DMA2CNT_L   + 1: dma9.write_DMAXCNT_L  (1, data, 2); break;
            case DMA2CNT_H   + 0: dma9.write_DMAXCNT_H  (0, data, 2); break;
            case DMA2CNT_H   + 1: dma9.write_DMAXCNT_H  (1, data, 2); break;
            case DMA3SAD     + 0: dma9.write_DMAXSAD    (0, data, 3); break;
            case DMA3SAD     + 1: dma9.write_DMAXSAD    (1, data, 3); break;
            case DMA3SAD     + 2: dma9.write_DMAXSAD    (2, data, 3); break;
            case DMA3SAD     + 3: dma9.write_DMAXSAD    (3, data, 3); break;
            case DMA3DAD     + 0: dma9.write_DMAXDAD    (0, data, 3); break;
            case DMA3DAD     + 1: dma9.write_DMAXDAD    (1, data, 3); break;
            case DMA3DAD     + 2: dma9.write_DMAXDAD    (2, data, 3); break;
            case DMA3DAD     + 3: dma9.write_DMAXDAD    (3, data, 3); break;
            case DMA3CNT_L   + 0: dma9.write_DMAXCNT_L  (0, data, 3); break;
            case DMA3CNT_L   + 1: dma9.write_DMAXCNT_L  (1, data, 3); break;
            case DMA3CNT_H   + 0: dma9.write_DMAXCNT_H  (0, data, 3); break;
            case DMA3CNT_H   + 1: dma9.write_DMAXCNT_H  (1, data, 3); break;

            default: error_unimplemented("MMIO 9 register %x written to with value %x; This register does not exist.", address, data); break;
        }
    }
}