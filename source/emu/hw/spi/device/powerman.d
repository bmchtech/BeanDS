module emu.hw.spi.device.powerman;

import emu.hw.spi.device;
import util;

__gshared PowerMan powerman;
final class PowerMan : SPIDevice {
    // powerman control
    bool sound_amp_enable;
    bool sound_amp_mute;
    bool lower_backlight;
    bool upper_backlight;
    bool power_led_blink_enable;
    bool power_led_blink_speed;
    bool ds_system_power;

    // battery status
    bool battery_power_led_status;

    // mic amp control
    bool amplifier_enable;

    // mic amp gain control
    int gain;

    enum Register {
        CONTROL              = 0,
        BATTERY_STATUS       = 1,
        MIC_AMP_CONTROL      = 2,
        MIC_AMP_GAIN_CONTROL = 3,
    }
    
    this() {
        powerman = this;
        state = State.WAITING_FOR_CHIPSELECT;
    }

    enum State {
        WAITING_FOR_COMMAND,
        WAITING_FOR_CHIPSELECT,
        PROCESSING_COMMAND
    }

    State state;
    Register register;
    bool read;

    override Byte write(Byte b) {
        Byte result = 0;

        final switch (state) {
            case State.WAITING_FOR_COMMAND:
                register = cast(Register) (b[0..6] & ~4);
                read     = b[7];
                state = State.PROCESSING_COMMAND;
                break;
            
            case State.PROCESSING_COMMAND:
                if (read) result = read_current_register();
                else write_current_register(b);
                
                state = State.WAITING_FOR_CHIPSELECT;
                break;
            
            case State.WAITING_FOR_CHIPSELECT:
                break;
        }

        return result;
    }

    Byte read_current_register() {
        Byte result;

        final switch (register) {
            case Register.CONTROL:
                result[0] = sound_amp_enable;
                result[1] = sound_amp_mute;
                result[2] = lower_backlight;
                result[3] = upper_backlight;
                result[4] = power_led_blink_enable;
                result[5] = power_led_blink_speed;
                result[6] = ds_system_power;
                break;
            
            case Register.BATTERY_STATUS:
                result[0] = battery_power_led_status;
                break;
            
            case Register.MIC_AMP_CONTROL:
                result[0] = amplifier_enable;
                break;
            
            case Register.MIC_AMP_GAIN_CONTROL:
                result[0] = gain;
                break;
        }

        return result;
    }

    void write_current_register(Byte b) {
        final switch (register) {
            case Register.CONTROL:
                sound_amp_enable       = b[0];
                sound_amp_mute         = b[1];
                lower_backlight        = b[2];
                upper_backlight        = b[3];
                power_led_blink_enable = b[4];
                power_led_blink_speed  = b[5];
                ds_system_power        = b[6];
                break;
            
            case Register.BATTERY_STATUS:
                // read-only
                break;
            
            case Register.MIC_AMP_CONTROL:
                amplifier_enable = b[0];
                break;
            
            case Register.MIC_AMP_GAIN_CONTROL:
                gain = b[0];
                break;
        }

    }

    override void chipselect_rise() {
        state = State.WAITING_FOR_CHIPSELECT;
    }

    override void chipselect_fall() {
        state = State.WAITING_FOR_COMMAND;
    }
}