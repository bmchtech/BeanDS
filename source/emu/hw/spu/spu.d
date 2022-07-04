module emu.hw.spu.spu;

import emu;
import util;

import ui.device;

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

    this() {
    }

    void reset() {
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
            int  extra_cycles;
            int  cycles_since_last_sample_was_calculated;
        }

        void reset() {
            current_address = source_address;
            current_sample  = Sample(0, 0);
            cycles_since_last_sample_was_calculated = 0;
        }

        Sample get_sample() {
            if (!enabled) return Sample(0, 0);

            cycles_since_last_sample_was_calculated += spu.cycles_per_sample;

            auto cycles_till_calculate_next_sample = (0x10000 - timer_value) * 2;

            while (cycles_since_last_sample_was_calculated > cycles_till_calculate_next_sample) {
                calculate_next_sample();
                cycles_since_last_sample_was_calculated -= cycles_till_calculate_next_sample;
            }

            Sample sample;
            sample.L = cast(short) (current_sample.L * (127 - panning) / 128);
            sample.R = cast(short) (current_sample.R * (      panning) / 128);
            return sample;
        }
                
        void calculate_next_sample() {
            Half sample_data = 0;

            switch (format) {
                case Format.PCM16:
                    sample_data = mem9.read!Half(current_address);
                    this.current_address += 2;
                    break;
                
                default:
                    break;
            }

            if (repeat_mode == RepeatMode.LOOP_INF && current_address >= source_address + length * 4) {
                this.current_address = this.source_address;
            }
            
            current_sample = Sample(sample_data, sample_data);
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
                    log_spu("Channel Enabled: %x. CNT: %08x SAD: %04x TMR: %04x PNT: %04x LEN: %08x", 
                        x,
                        ((cast(int) read_SOUNDxCNT(0, x) << 0) |
                        (cast(int) read_SOUNDxCNT(1, x) << 8) |
                        (cast(int) read_SOUNDxCNT(2, x) << 16) |
                        (cast(int) read_SOUNDxCNT(3, x) << 24)),
                        sound_channels[x].source_address,
                        sound_channels[x].timer_value,
                        sound_channels[x].loopstart,
                        sound_channels[x].length,
                    );
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
            Sample channel_sample = sound_channels[i].get_sample();
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