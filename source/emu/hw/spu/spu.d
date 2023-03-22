module emu.hw.spu.spu;

import emu.hw.memory.mem9;
import emu.hw.memory.strategy.memstrategy;
import emu.scheduler;
import ui.device;
import util;

static immutable int[] IMA_INDEX_TABLE = [
    -1, -1, -1, -1, 2, 4, 6, 8
];

static immutable short[] ADPCM_TABLE = [
    0x0007, 0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E,
    0x0010, 0x0011, 0x0013, 0x0015, 0x0017, 0x0019, 0x001C, 0x001F,
    0x0022, 0x0025, 0x0029, 0x002D, 0x0032, 0x0037, 0x003C, 0x0042,
    0x0049, 0x0050, 0x0058, 0x0061, 0x006B, 0x0076, 0x0082, 0x008F,
    0x009D, 0x00AD, 0x00BE, 0x00D1, 0x00E6, 0x00FD, 0x0117, 0x0133,
    0x0151, 0x0173, 0x0198, 0x01C1, 0x01EE, 0x0220, 0x0256, 0x0292,
    0x02D4, 0x031C, 0x036C, 0x03C3, 0x0424, 0x048E, 0x0502, 0x0583,
    0x0610, 0x06AB, 0x0756, 0x0812, 0x08E0, 0x09C3, 0x0ABD, 0x0BD0,
    0x0CFF, 0x0E4C, 0x0FBA, 0x114C, 0x1307, 0x14EE, 0x1706, 0x1954,
    0x1BDC, 0x1EA5, 0x21B6, 0x2515, 0x28CA, 0x2CDF, 0x315B, 0x364B,
    0x3BB9, 0x41B2, 0x4844, 0x4F7E, 0x5771, 0x602F, 0x69CE, 0x7462,
    0x7FFF
];

// TODO: REMOVE!
static bool shouldLog = 0;

__gshared SPU spu;
final class SPU {
    int cycles_per_sample;

    void delegate(Sample s) push_sample_callback;

    short master_volume;
    bool master_enable;
    OutputSource output_source_left;
    OutputSource output_source_right;
    bool output_mixer_ch1 = true;
    bool output_mixer_ch3 = true;
    Half sound_bias;

    Mem mem;

    enum OutputSource {
        MIXER        = 0,
        CH1          = 1,
        CH3          = 2,
        CH1_PLUS_CH3 = 3
    }
    
    enum Format {
        PCM8      = 0,
        PCM16     = 1,
        IMA_ADPCM = 2,
        PSG_NOISE = 3
    }

    enum RepeatMode {
        MANUAL   = 0,
        LOOP_INF = 1,
        ONESHOT  = 2,
        UNKNOWN  = 3,
    }

    this(Mem mem) {
        this.mem = mem;
    }

    void reset() {
        log_gpu3d("spu reset()");
        scheduler.add_event_relative_to_self(&sample, cycles_per_sample);
    }

    struct SoundChannel {
        public {
            int volume_mul;
            int volume_div;
            bool hold;
            int panning;
            int wave_duty;
            int repeat_mode;
            int format;
            bool enabled;

            Word source_address;
            Word timer_value;
            Word loopstart;
            Word length;
        }

        private {
            Word current_address;
            Sample current_sample;
            bool half_read;
            int  extra_cycles;
            int  cycles_since_last_sample_was_calculated;

            Byte  ima_byte;
            short ima_pcm16bit;
            int   ima_index;
        }

        void reset() {
            current_address = source_address;
            current_sample  = Sample(0, 0);
            cycles_since_last_sample_was_calculated = 0;
            half_read = 0;
        }

        Sample get_sample(Mem mem) {
            if (!enabled) return Sample(0, 0);

            cycles_since_last_sample_was_calculated += spu.cycles_per_sample;

            auto cycles_till_calculate_next_sample = (0x10000 - timer_value) * 2;

            while (cycles_since_last_sample_was_calculated > cycles_till_calculate_next_sample) {
                calculate_next_sample(mem);
                cycles_since_last_sample_was_calculated -= cycles_till_calculate_next_sample;
            }

            Sample sample;
            sample.L = cast(short) (current_sample.L * (127 - panning) / 128);
            sample.R = cast(short) (current_sample.R * (      panning) / 128);
            return sample;
        }
                
        void calculate_next_sample(Mem mem) {
            short sample_data = 0;

            // OMG STARVING INDIE DEV PRODUCT NINTENDO SWITCH HOME OF CELESTE AND HOLLOW KNIGHT AND SUPER MARIO
            // OMG OMG OMG OMG OMG BUY RN
            switch (format) {
                case Format.PCM16:
                    sample_data = mem.read_data_half7(current_address);
                    this.current_address += 2;
                    break;
                case Format.PCM8:
                    sample_data = cast(short)(( mem.read_data_byte7(current_address)) << 8);
                    this.current_address += 1;
                    break;
                case Format.IMA_ADPCM:
                    if (this.current_address == this.source_address) {
                        if (shouldLog) {
                            log_spu("--------------------------------");
                            log_spu("Reading IMA Header");
                            log_spu("IMA Source Address: %d", this.source_address);
                            log_spu("--------------------------------");
                        }                       
                        Word header_data = mem.read_data_word7(current_address);
                        this.ima_pcm16bit = cast(short) header_data[0..15];
                        this.ima_index = header_data[16..22];
                        this.ima_index &= 0x7F;
                        this.current_address += 4;
                        this.half_read = 0;
                    }
                    else {
                        byte data4bit = 0;
                        if (!this.half_read) {
                            if (shouldLog) {
                                log_spu("IMA Half Read 1");
                                log_spu("IMA Current Address: %d", this.current_address);
                            }
                            this.ima_byte = mem.read_data_byte7(current_address);
                            data4bit = this.ima_byte[0..3];
                            this.half_read = 1;
                        }
                        else {
                            if (shouldLog) {
                                log_spu("IMA Half Read 2");
                                log_spu("IMA Current Address: %d", this.current_address);
                            }
                            data4bit = this.ima_byte[4..7];
                            this.half_read = 0;
                            this.current_address += 1;
                        }
                        // Interpret sample 
                        data4bit &= 0x0F; // Zero out top bits
                        sample_data = interpret_ima_sample(data4bit);
                        // Should increment address be done here?
                    }
                    break;
                default:
                    break;
            }

            // IMA_ADPCM should rewind to the first sample, not header
            // Sound Model:
            // [PNT][LEN]
            // Loop: [PNT][LEN][LEN][LEN][LEN][LEN][LEN]
            // PNT + LEN = N words
            // PCM8:  4N     samples
            // PCM16: 2N     samples
            // IMA:   8(N-1) samples
            if (repeat_mode == RepeatMode.LOOP_INF) {

                if (format != Format.IMA_ADPCM &&
                    current_address >= source_address + length * 4) {
                    this.current_address = this.source_address;
                }
                else if (format == Format.IMA_ADPCM &&
                    current_address >= source_address + (8*(length - 1))) {
                    this.current_address = this.source_address + 4;
                }
            }
            
            current_sample = Sample(sample_data, sample_data);
        }

        short interpret_ima_sample(byte data4bit) {
            short pcm16bit = this.ima_pcm16bit;
            short adpentry = cast(short) (this.ima_index > 88) ?
                0 : ADPCM_TABLE[this.ima_index];
            short diff = adpentry / 8;

            if (data4bit & 1) 
                diff += adpentry / 4;
            if (data4bit & 2)
                diff += adpentry / 2;
            if (data4bit & 4)
                diff += adpentry / 1;

            if (!(data4bit & 8)) {
                if (pcm16bit + diff < 0x7fff) 
                    pcm16bit += diff;
                else
                    pcm16bit = 0x7fff;
            }
            if ((data4bit & 8) == 8) {
                if (pcm16bit - diff > -0x7fff)
                    pcm16bit -= diff;
                else
                    pcm16bit = -0x7fff;
            }
            
            this.ima_index = this.ima_index + IMA_INDEX_TABLE[data4bit & 7];
            if (this.ima_index < 0) 
                this.ima_index = 0;
            if (this.ima_index > 88)
                this.ima_index = 88;

            return pcm16bit;
        }
    }

    SoundChannel[16] sound_channels;

    Byte read_SOUNDxCNT(int target_byte, int x) {
        Byte result;
        
        final switch (target_byte) {
             case 0:
                result[0..6] = sound_channels[x].volume_mul;
                break;
            case 1:
                result[0..1] = sound_channels[x].volume_div;
                break;
            case 2:
                result[0..6] = sound_channels[x].panning;
                break;
            case 3:
                result[0..2] = sound_channels[x].wave_duty;
                result[3..4] = cast(RepeatMode) sound_channels[x].repeat_mode;
                result[5..6] = cast(Format) sound_channels[x].format;
                result[7]    = sound_channels[x].enabled;
                break;
        }

        return result;
    }

    void write_SOUNDxCNT(int target_byte, Byte value, int x) {
        final switch (target_byte) {
             case 0:
                sound_channels[x].volume_mul  = value[0..6];
                break;
            case 1:
                sound_channels[x].volume_div  = value[0..1];
                break;
            case 2:
                sound_channels[x].panning     = value[0..6];
                break;
            case 3:
                sound_channels[x].wave_duty   = value[0..2];
                sound_channels[x].repeat_mode = value[3..4];
                sound_channels[x].format      = value[5..6];
                sound_channels[x].enabled     = value[7];

                if (sound_channels[x].enabled) { 
                    sound_channels[x].reset(); 
                    // log_spu("Channel Enabled: %x. %s CNT: %08x SAD: %04x TMR: %04x PNT: %04x LEN: %08x", 
                    //     x,
                    //     cast(Format) sound_channels[x].format,
                    //     ((cast(int) read_SOUNDxCNT(0, x) << 0) |
                    //     (cast(int) read_SOUNDxCNT(1, x) << 8) |
                    //     (cast(int) read_SOUNDxCNT(2, x) << 16) |
                    //     (cast(int) read_SOUNDxCNT(3, x) << 24)),
                    //     sound_channels[x].source_address,
                    //     sound_channels[x].timer_value,
                    //     sound_channels[x].loopstart,
                    //     sound_channels[x].length,
                    // );
                }
                break;
        }
    }

    void write_SOUNDxSAD(int target_byte, Byte value, int x) {
        sound_channels[x].source_address.set_byte(target_byte, value);
        sound_channels[x].source_address &= create_mask(0, 26);
    }

    void write_SOUNDxTMR(int target_byte, Byte value, int x) {
        sound_channels[x].timer_value.set_byte(target_byte, value);
    }

    void write_SOUNDxPNT(int target_byte, Byte value, int x) {
        sound_channels[x].loopstart.set_byte(target_byte, value);
    }

    void write_SOUNDxLEN(int target_byte, Byte value, int x) {
        sound_channels[x].length.set_byte(target_byte, value);
    }
    
    Byte read_SOUNDCNT(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0..6] = master_volume;
                break;

            case 1: 
                result[0..1] = output_source_left;
                result[2..3] = output_source_right;
                result[4]    = !output_mixer_ch1;
                result[5]    = !output_mixer_ch3;
                result[7]    = master_enable; 
                break;
        }

        return result;
    }
    
    void write_SOUNDCNT(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0: 
                master_volume = value[0..6];
                break;

            case 1:
                output_source_left  = cast(OutputSource) value[0..1];
                output_source_right = cast(OutputSource) value[2..3];
                output_mixer_ch1    = !value[4];
                output_mixer_ch3    = !value[5];
                master_enable       = value[7];
                break;
        }
    }
    
    Byte read_SOUNDBIAS(int target_byte) {
        return sound_bias.get_byte(target_byte);
    }
    
    void write_SOUNDBIAS(int target_byte, Byte value) {
        sound_bias.set_byte(target_byte, value);
        sound_bias &= 0x3FF;
    }

    void set_push_sample_callback(void delegate(Sample s) push_sample_callback) {
        this.push_sample_callback = push_sample_callback;
    }
    
    void sample() {
        Sample result = Sample(0, 0);
        for (int i = 0; i < 16; i++) {
            shouldLog = (i == 4) ? 1 : 0; // TODO: Remove!!
            Sample channel_sample = sound_channels[i].get_sample(mem);
            result.L += channel_sample.L;
            result.R += channel_sample.R;
        }

        result.L += sound_bias;
        result.R += sound_bias;

        push_sample_callback(result);
        scheduler.add_event_relative_to_self(&sample, cycles_per_sample);
    }

    void set_cycles_per_sample(int cycles_per_sample) {
        this.cycles_per_sample = cycles_per_sample;
    }
}