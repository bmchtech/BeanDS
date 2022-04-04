module emu.hw.spu.spu;

import emu;
import util;

import ui.device;

__gshared SPU spu;
final class SPU {
    int cycles_per_sample;

    void delegate(Sample s) push_sample_callback;

    bool master_enable;

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
        }

        void reset() {
            current_address = source_address;
            extra_cycles    = 0;
            current_sample  = 0;
        }

        short sample() {
            if (!enabled) return 0;

            auto cycles_since_last_sample = spu.cycles_per_sample - extra_cycles;
            auto dmas_since_last_sample   = cycles_since_last_sample / timer_value;
            extra_cycles                  = cycles_since_last_sample % timer_value;

            current_address += dmas_since_last_sample * 2;
            current_sample = mem7.read!Half(current_address);

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

        return result;
    }

    void write_SOUNDxCNT(int target_byte, Byte value, int x) {
        auto c = sound_channels[x];
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
        return Byte(0);
    }
    
    void write_SOUNDCNT(int target_byte, Byte value) {
        
    }
    
    Byte read_SOUNDBIAS(int target_byte) {
        return Byte(0);
    }
    
    void write_SOUNDBIAS(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0: 
                // bruh im too lazy to program the rest of these values in
                break;

            case 1:
                master_enable = value[7];
                break;
        }
    }

    void set_push_sample_callback(void delegate(Sample s) push_sample_callback) {
        this.push_sample_callback = push_sample_callback;
    }
    
    void sample() {
        short result = 0;
        for (int i = 0; i < 16; i++) result += sound_channels[i].sample();
        push_sample_callback(Sample(result, result));

        scheduler.add_event_relative_to_self(&sample, cycles_per_sample);
    }

    void set_cycles_per_sample(int cycles_per_sample) {
        this.cycles_per_sample = cycles_per_sample;
    }
}