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

    private this() {
        scheduler.add_event_relative_to_self(&sample, cycles_per_sample);
    }

    static void reset() {
        spu = new SPU();
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
            Half current_sample;
            int  extra_cycles;
            int  cycles_since_last_dma;
        }

        void reset() {
            current_address = source_address;
            current_sample  = 0;
            cycles_since_last_dma = 0;
        }

        short sample() {
            if (!enabled) return 0;

            cycles_since_last_dma += spu.cycles_per_sample;

            auto cycles_till_dma_increment = (0x10000 - timer_value) * 2;

            if (cycles_since_last_dma > cycles_till_dma_increment) {
                current_address += (cycles_since_last_dma / cycles_till_dma_increment) * 2;
                
                if (repeat_mode == 1 && current_address >= source_address + length * 4) current_address = source_address;

                cycles_since_last_dma %= cycles_till_dma_increment;
                current_sample = mem9.read!Half(current_address);
            }

            return current_sample;
        }
    }

    SoundChannel[16] sound_channels;

    Byte read_SOUNDxCNT(int target_byte, int x) {
        Byte result = 0;
        auto c = sound_channels[x];
        
        final switch (target_byte) {
             case 0:
                result[0..6] = c.volume_mul;
                break;
            case 1:
                result[0..1] = c.volume_div;
                break;
            case 2:
                result[0..6] = c.panning;
                break;
            case 3:
                result[0..2] = c.wave_duty;
                result[3..4] = c.repeat_mode;
                result[5..6] = c.format;
                result[7]    = c.enabled;
                break;
        }
        log_spu("read from soundcunt %x %x %x", target_byte, result, 0);

        return result;
    }

    void write_SOUNDxCNT(int target_byte, Byte value, int x) {
        log_spu("wrote to soundcunt %x %x %x", target_byte, value, x);
        auto c = &sound_channels[x];
        final switch (target_byte) {
             case 0:
                c.volume_mul  = value[0..6];
                break;
            case 1:
                c.volume_div  = value[0..1];
                break;
            case 2:
                c.panning     = value[0..6];
                break;
            case 3:
                c.wave_duty   = value[0..2];
                c.repeat_mode = value[3..4];
                c.format      = value[5..6];
                c.enabled     = value[7];

                if (c.enabled) c.reset();
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

        log_spu("read from soundCuNT %x %x %x", target_byte, result, 0);
        return result;
    }
    
    void write_SOUNDCNT(int target_byte, Byte value) {
        log_spu("wrote to soundCuNT %x %x %x", target_byte, value, 0);
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
            short channel_sample = sound_channels[i].sample();
            result.L += channel_sample * (127 - sound_channels[i].panning) / 128;
            result.R += channel_sample * (      sound_channels[i].panning) / 128;
        }

        result.L += 0x200;
        result.R += 0x200;
        // if (result.L < 0) result.L = 0;
        // if (result.R < 0) result.R = 0;

        push_sample_callback(result);

        scheduler.add_event_relative_to_self(&sample, cycles_per_sample);
    }

    void set_cycles_per_sample(int cycles_per_sample) {
        this.cycles_per_sample = cycles_per_sample;
    }
}