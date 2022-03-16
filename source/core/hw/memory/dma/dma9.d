module core.hw.memory.dma.dma9;

import core.hw.memory;

import util;

__gshared DMA9 dma9;
final class DMA9 {
    Mem9 mem9;

    this(Mem9 mem9) {
        this.mem9 = mem9;
        dma9 = this;

        dma_channels = [
            DMAChannel(Word(0), Word(0), Half(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
            DMAChannel(Word(0), Word(0), Half(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
            DMAChannel(Word(0), Word(0), Half(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
            DMAChannel(Word(0), Word(0), Half(0), 0, 0, 0, false, false, false, false, false, false, DestAddrMode.Increment, SourceAddrMode.Increment, DMAStartTiming.Immediately,),
        ];
    }

    void handle_dma() {
        // get the channel with highest priority that wants to start dma
        int current_channel = -1;
        for (int i = 0; i < 4; i++) {
            if (dma_channels[i].enabled && dma_channels[i].waiting_to_start) {
                current_channel = i;
                break;
            }
        }
        
        if (current_channel == -1) return;

        auto bytes_to_transfer = dma_channels[current_channel].size_buf;

        log_dma9(
            "DMA Channel %x running: Transferring %x %s from %x to %x (Control: %x)",
            current_channel,
            bytes_to_transfer,
            dma_channels[current_channel].transferring_words ? "words" : "halfwords",
            dma_channels[current_channel].source_buf,
            dma_channels[current_channel].dest_buf,
            read_DMAXCNT_H(0, current_channel) | (read_DMAXCNT_H(1, current_channel) << 8)
        );

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

                Word value = mem9.read_word(read_address);
                mem9.write_word(write_address, value);

                source_offset += source_increment;
                dest_offset   += dest_increment;
            }
        } else {
            bytes_to_transfer *= 2;

            for (int i = 0; i < bytes_to_transfer; i += 2) {
                Word read_address  = dma_channels[current_channel].source_buf + source_offset;
                Word write_address = dma_channels[current_channel].dest_buf   + dest_offset;

                Half value = mem9.read_half(read_address);
                mem9.write_half(write_address, value);

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

    const uint[4] DMA_SOURCE_BUF_MASK = [0x07FF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF, 0x0FFF_FFFF];
    const uint[4] DMA_DEST_BUF_MASK   = [0x07FF_FFFF, 0x07FF_FFFF, 0x07FF_FFFF, 0x0FFF_FFFF];

    void initialize_dma(int dma_id) {
        dma_channels[dma_id].source_buf = dma_channels[dma_id].source & (dma_channels[dma_id].transferring_words ? ~3 : ~1);
        dma_channels[dma_id].dest_buf   = dma_channels[dma_id].dest   & (dma_channels[dma_id].transferring_words ? ~3 : ~1);
    
        dma_channels[dma_id].source_buf &= DMA_SOURCE_BUF_MASK[dma_id];
        dma_channels[dma_id].dest_buf   &= DMA_DEST_BUF_MASK[dma_id];
    }

    void enable_dma(int dma_id) {
        dma_channels[dma_id].num_units = dma_channels[dma_id].num_units & 0x0001FFFF;
        if (dma_channels[dma_id].num_units) dma_channels[dma_id].num_units = 0x20000;

        dma_channels[dma_id].enabled  = true;

        dma_channels[dma_id].size_buf = dma_channels[dma_id].num_units;

        if (dma_channels[dma_id].dma_start_timing == DMAStartTiming.Immediately) {
            dma_channels[dma_id].repeat = false;
            start_dma_channel(dma_id, false);
        } else {
            error_unimplemented("A non immediate DMA9 was enabled");
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
        Half  num_units;

        uint   source_buf;
        uint   dest_buf;
        ushort size_buf;
        
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

    void write_DMAXSAD(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0: dma_channels[x].source[0 .. 7] = data; break;
            case 1: dma_channels[x].source[8 ..15] = data; break;
            case 2: dma_channels[x].source[16..23] = data; break;
            case 3: dma_channels[x].source[24..31] = data; break;
        }
    }

    void write_DMAXDAD(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0: dma_channels[x].dest[0 .. 7] = data; break;
            case 1: dma_channels[x].dest[8 ..15] = data; break;
            case 2: dma_channels[x].dest[16..23] = data; break;
            case 3: dma_channels[x].dest[24..31] = data; break;
        }
    }

    void write_DMAXCNT_L(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0b0: dma_channels[x].num_units[0 .. 7] = data; break;
            case 0b1: dma_channels[x].num_units[8 ..15] = data; break;
        }
    }

    void write_DMAXCNT_H(int target_byte, Byte data, int x) {
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

    Byte read_DMAXSAD(int target_byte, int x) {
        final switch (target_byte) {
            case 0: return cast(Byte) dma_channels[x].source[0.. 7];
            case 1: return cast(Byte) dma_channels[x].source[8.. 15];
            case 2: return cast(Byte) dma_channels[x].source[16..23];
            case 3: return cast(Byte) dma_channels[x].source[24..31];
        }
    }

    Byte read_DMAXDAD(int target_byte, int x) {
        final switch (target_byte) {
            case 0: return cast(Byte) dma_channels[x].dest[0 ..7];
            case 1: return cast(Byte) dma_channels[x].dest[8 ..15];
            case 2: return cast(Byte) dma_channels[x].dest[16..23];
            case 3: return cast(Byte) dma_channels[x].dest[24..31];
        }
    }

    Byte read_DMAXCNT_L(int target_byte, int x) {
        final switch (target_byte) {
            case 0: return cast(Byte) dma_channels[x].num_units[0..7];
            case 1: return cast(Byte) dma_channels[x].num_units[8..15];
        }
    }

    Byte read_DMAXCNT_H(int target_byte, int x) {
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
}