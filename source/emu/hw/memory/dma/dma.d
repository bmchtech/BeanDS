module emu.hw.memory.dma.dma;

import emu;
import util;

__gshared DMA!(HwType.NDS7) dma7;
__gshared DMA!(HwType.NDS9) dma9;

static void DMA_reset() {
    dma7 = new DMA!(HwType.NDS7)();
    dma9 = new DMA!(HwType.NDS9)();
}

final class DMA(HwType H) {
    private this() {
        dma_channels = [
            DMAChannel(Word(0), Word(0), Word(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
            DMAChannel(Word(0), Word(0), Word(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
            DMAChannel(Word(0), Word(0), Word(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
            DMAChannel(Word(0), Word(0), Word(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
        ];
    }

    static if (H == HwType.NDS9) alias mem = mem9;
    static if (H == HwType.NDS7) alias mem = mem7;

    void handle_dma() {
        // get the channel with highest priority that wants to start dma
        int current_channel = -1;
        for (int i = 0; i < 4; i++) {
            if (dma_channels[i].enabled) {
                current_channel = i;
                break;
            }
        }
        
        if (current_channel == -1) return;

        auto bytes_to_transfer = dma_channels[current_channel].size_buf;

        // log_dma7(
        //     "DMA Channel %x running: Transferring %x %s from %x to %x (Control: %x)",
        //     current_channel,
        //     bytes_to_transfer,
        //     dma_channels[current_channel].transferring_words ? "words" : "halfwords",
        //     dma_channels[current_channel].source_buf,
        //     dma_channels[current_channel].dest_buf,
        //     read_DMAxCNT_H(0, current_channel) | (read_DMAxCNT_H(1, current_channel) << 8)
        // );

        auto source_increment = 0;
        auto dest_increment = 0;

        switch (dma_channels[current_channel].source_addr_control) {
            case SourceAddrMode.Increment:  source_increment =  1; break;
            case SourceAddrMode.Decrement:  source_increment = -1; break;
            case SourceAddrMode.Fixed:      source_increment =  0; break;
            default: assert(0);
        }

        switch (dma_channels[current_channel].dest_addr_control) {
            case DestAddrMode.Increment:       dest_increment =  1; break;
            case DestAddrMode.Decrement:       dest_increment = -1; break;
            case DestAddrMode.Fixed:           dest_increment =  0; break;
            case DestAddrMode.IncrementReload: dest_increment =  1; break;
            default: assert(0);
        }

        source_increment *= (dma_channels[current_channel].transferring_words ? 4 : 2);
        dest_increment   *= (dma_channels[current_channel].transferring_words ? 4 : 2);

        int source_offset = 0;
        int dest_offset   = 0;

        AccessType access_type = AccessType.NONSEQUENTIAL;

        if (dma_channels[current_channel].transferring_words) {
            bytes_to_transfer *= 4;
            for (int i = 0; i < bytes_to_transfer; i += 4) {
                Word read_address  = dma_channels[current_channel].source_buf + source_offset;
                Word write_address = dma_channels[current_channel].dest_buf   + dest_offset;

                Word value = mem.read_word(read_address);
                mem.write_word(write_address, value);
                // log_dma7("    Transferred %08x from %x to %x", value, read_address, write_address);

                source_offset += source_increment;
                dest_offset   += dest_increment;
            }
        } else {
            bytes_to_transfer *= 2;

            for (int i = 0; i < bytes_to_transfer; i += 2) {
                Word read_address  = dma_channels[current_channel].source_buf + source_offset;
                Word write_address = dma_channels[current_channel].dest_buf   + dest_offset;

                Half value = mem.read_half(read_address);
                mem.write_half(write_address, value);
                // log_dma7("    Transferred %04x from %x to %x", value, read_address, write_address);

                source_offset += source_increment;
                dest_offset   += dest_increment;
            }
        }

        dma_channels[current_channel].source_buf += source_offset;
        dma_channels[current_channel].dest_buf   += dest_offset;
        
        if (dma_channels[current_channel].irq_on_end) {
            error_unimplemented("DMA9 requested an interrupt");
        }

        if (dma_channels[current_channel].repeat) {
            if (dma_channels[current_channel].dest_addr_control == DestAddrMode.IncrementReload) {
                dma_channels[current_channel].dest_buf = dma_channels[current_channel].dest;
            }

            enable_dma(current_channel);
        } else {
            dma_channels[current_channel].enabled = false;
        }
    }

    static if (is(H == HwType.NDS7)) {
        const uint[4] DMA_SOURCE_BUF_MASK = [0x07FF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF];
        const uint[4] DMA_DEST_BUF_MASK   = [0x07FF_FFFF, 0x07FF_FFFF, 0x07FF_FFFF, 0x0FFF_FFFF];
        const uint[4] DMA_NUM_UNITS_MASK  = [0x0000_3FFF, 0x0000_3FFF, 0x0000_3FFF, 0x0000_FFFF];
    } else { // NDS9
        const uint[4] DMA_SOURCE_BUF_MASK = [0x0FFF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF];
        const uint[4] DMA_DEST_BUF_MASK   = [0x0FFF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF];
        const uint[4] DMA_NUM_UNITS_MASK  = [0x0001_FFFF, 0x0001_FFFF, 0x0001_FFFF, 0x0001_FFFF];
    }

    void initialize_dma(int dma_id) {
        dma_channels[dma_id].source_buf = dma_channels[dma_id].source & (dma_channels[dma_id].transferring_words ? ~3 : ~1);
        dma_channels[dma_id].dest_buf   = dma_channels[dma_id].dest   & (dma_channels[dma_id].transferring_words ? ~3 : ~1);
    
        dma_channels[dma_id].source_buf &= DMA_SOURCE_BUF_MASK[dma_id];
        dma_channels[dma_id].dest_buf   &= DMA_DEST_BUF_MASK[dma_id];
    }

    void enable_dma(int dma_id) {
        dma_channels[dma_id].num_units = dma_channels[dma_id].num_units & DMA_NUM_UNITS_MASK[dma_id];

        dma_channels[dma_id].enabled  = true;

        dma_channels[dma_id].size_buf = dma_channels[dma_id].num_units;

        if (dma_channels[dma_id].dma_start_timing == DMAStartTiming.Immediately) {
            dma_channels[dma_id].repeat = false;
            start_dma_channel(dma_id, false);
        }
    }

    pragma(inline, true) void start_dma_channel(int dma_id, bool last) {
        handle_dma();
    }

    void on_hblank(uint scanline) {
        for (int i = 0; i < 4; i++) {
            if (dma_channels[i].dma_start_timing == DMAStartTiming.HBlank) {
                start_dma_channel(i, false);
            }
        }
    }

    void on_vblank() {
        for (int i = 0; i < 4; i++) {
            if (dma_channels[i].dma_start_timing == DMAStartTiming.VBlank) {
                start_dma_channel(i, false);
            }
        }
    }

    DMAChannel[4] dma_channels;
    Word[4] dma_fill_registers;

    enum SourceAddrMode {
        Increment       = 0b00,
        Decrement       = 0b01,
        Fixed           = 0b10,
        Prohibited      = 0b11
    }

    enum DestAddrMode {
        Increment       = 0b00,
        Decrement       = 0b01,
        Fixed           = 0b10,
        IncrementReload = 0b11
    }

    enum DMAStartTiming {
        Immediately       = 0,
        VBlank            = 1,
        HBlank            = 2,
        VDraw             = 3,
        MainMemoryDisplay = 4,
        DSCartSlot        = 5,
        GBACartSlot       = 6,
        GeometryCmdFifo   = 7
    }

    struct DMAChannel {
        Word  source;
        Word  dest;
        Word  num_units;

        uint   source_buf;
        uint   dest_buf;
        uint   size_buf;
        
        bool   enabled;
        bool   waiting_to_start;
        bool   repeat;
        bool   transferring_words;
        bool   irq_on_end;

        uint   open_bus_latch;

        DestAddrMode   dest_addr_control;
        SourceAddrMode source_addr_control;
        DMAStartTiming dma_start_timing;
    }

    void write_DMAxSAD(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0: dma_channels[x].source[0 .. 7] = data; break;
            case 1: dma_channels[x].source[8 ..15] = data; break;
            case 2: dma_channels[x].source[16..23] = data; break;
            case 3: dma_channels[x].source[24..31] = data; break;
        }
    }

    void write_DMAxDAD(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0: dma_channels[x].dest[0 .. 7] = data; break;
            case 1: dma_channels[x].dest[8 ..15] = data; break;
            case 2: dma_channels[x].dest[16..23] = data; break;
            case 3: dma_channels[x].dest[24..31] = data; break;
        }
    }

    void write_DMAxCNT_L(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0b0: dma_channels[x].num_units[0 .. 7] = data; break;
            case 0b1: dma_channels[x].num_units[8 ..15] = data; break;
        }
    }

    void write_DMAxCNT_H(int target_byte, Byte data, int x) {
        import emu;
        
        final switch (target_byte) {
            case 0:
                dma_channels[x].num_units[16..20]   = data;
                dma_channels[x].dest_addr_control   = cast(DestAddrMode) data[5..6];
                dma_channels[x].source_addr_control = cast(SourceAddrMode) (data[7] | (dma_channels[x].source_addr_control & 0b10));
                break;
            case 1:
                dma_channels[x].source_addr_control = cast(SourceAddrMode) ((data[0] << 1) | (dma_channels[x].source_addr_control & 0b01));
                dma_channels[x].repeat              =  data[1];
                dma_channels[x].transferring_words  =  data[2];
                dma_channels[x].dma_start_timing    =  cast(DMAStartTiming) data[3..5];
                dma_channels[x].irq_on_end          =  data[6];
                dma_channels[x].enabled             =  data[7];

                if (data[7]) {
                    initialize_dma(x);
                    enable_dma(x);
                }

                break;
        }
    }

    void write_DMAxFILL(int target_byte, Byte data, int x) {
        dma_fill_registers[x].set_byte(target_byte, data);
    }

    Byte read_DMAxSAD(int target_byte, int x) {
        final switch (target_byte) {
            case 0: return cast(Byte) dma_channels[x].source[0.. 7];
            case 1: return cast(Byte) dma_channels[x].source[8.. 15];
            case 2: return cast(Byte) dma_channels[x].source[16..23];
            case 3: return cast(Byte) dma_channels[x].source[24..31];
        }
    }

    Byte read_DMAxDAD(int target_byte, int x) {
        final switch (target_byte) {
            case 0: return cast(Byte) dma_channels[x].dest[0 ..7];
            case 1: return cast(Byte) dma_channels[x].dest[8 ..15];
            case 2: return cast(Byte) dma_channels[x].dest[16..23];
            case 3: return cast(Byte) dma_channels[x].dest[24..31];
        }
    }

    Byte read_DMAxCNT_L(int target_byte, int x) {
        final switch (target_byte) {
            case 0: return cast(Byte) dma_channels[x].num_units[0..7];
            case 1: return cast(Byte) dma_channels[x].num_units[8..15];
        }
    }

    Byte read_DMAxCNT_H(int target_byte, int x) {
        final switch (target_byte) {
            case 0:
                return cast(Byte) ((dma_channels[x].dest_addr_control            << 5) |
                                  ((dma_channels[x].source_addr_control & 0b01) << 7));
            case 1:
                return cast(Byte) (((dma_channels[x].source_addr_control & 0b10) >> 1) |
                                    (dma_channels[x].repeat                      << 1) |
                                    (dma_channels[x].transferring_words          << 2) |
                                    (dma_channels[x].dma_start_timing            << 3) |
                                    (dma_channels[x].irq_on_end                  << 6) |
                                    (dma_channels[x].enabled                     << 7));
        }
    }

    Byte read_DMAxFILL(int target_byte, int x) {
        return dma_fill_registers[x].get_byte(target_byte);
    }
}