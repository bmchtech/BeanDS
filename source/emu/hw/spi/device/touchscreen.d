module emu.hw.spi.device.touchscreen;

import emu;
import util;

__gshared TouchScreen touchscreen;
final class TouchScreen : SPIDevice {
    this() {
        touchscreen = this;
        state = State.WAITING_FOR_CHIPSELECT;
    }

    // placeholder names because i really
    // dont understand how this works
    enum PowerDownMode {
        ZERO  = 0,
        ONE   = 1,
        TWO   = 2,
        THREE = 3
    }

    enum ReferenceSelect {
        DIFFERENTIAL = 0,
        SINGLE_ENDED = 1
    }

    enum ConversionMode {
        BIT_12 = 0,
        BIT_8  = 1
    }

    enum ChannelSelect {
        TEMPERATURE_0   = 0,
        TOUCHSCREEN_Y   = 1,
        BATTERY_VOLTAGE = 2,
        TOUCHSCREEN_Z1  = 3,
        TOUCHSCREEN_Z2  = 4,
        TOUCHSCREEN_X   = 5,
        AUX_INPUT       = 6,
        TEMPERATURE_1   = 7
    }

    enum State {
        WAITING_FOR_COMMAND,
        WAITING_FOR_CHIPSELECT,
        CALCULATING_COMMAND_RESPONSE
    }

    State state;

    PowerDownMode   power_down_mode;
    ReferenceSelect reference_select;
    ConversionMode  conversion_mode;
    ChannelSelect   channel_select;

    int x_position;
    int y_position;
    bool pen_down;

    override Half write(Byte b) {
        Half result = 0;

        final switch (state) {
            case State.WAITING_FOR_COMMAND:
                // bit 7 must be set in order for this command to be valid
                // it's the first bit thats received on the SPI bus (which
                // im not emulating bit by bit). and the first bit must be 1,
                // so we check that bit 7 here is 1 before continuing.
                if (!b[7]) {
                    log_touchscreen("received malformed touchscreen command: %x %x", b, arm7.regs[pc]);
                    result = 0;
                }

                power_down_mode  = cast(PowerDownMode)   b[0..1];
                reference_select = cast(ReferenceSelect) b[2];
                conversion_mode  = cast(ConversionMode)  b[3];
                channel_select   = cast(ChannelSelect)   b[4..6];
                state = State.CALCULATING_COMMAND_RESPONSE;
                break;
            
            case State.WAITING_FOR_CHIPSELECT:
                break;
            
            case State.CALCULATING_COMMAND_RESPONSE:
                final switch (channel_select) {
                    case ChannelSelect.TEMPERATURE_0:
                        // log_touchscreen("tried to read temperature 0");
                        result = 0x2F8;
                        break;
                    
                    case ChannelSelect.TOUCHSCREEN_Y:
                        result = input.keys[22] ? 0 : (y_position * (0xa0 - 0x20)) / 192;
                        // log_touchscreen("tried to read touchscreen pos y: %x", result);
                        break;
                    
                    case ChannelSelect.BATTERY_VOLTAGE:
                        result = 0;
                        break;

                    case ChannelSelect.TOUCHSCREEN_Z1:
                        // log_touchscreen("tried to read touchscreen z1");
                        result = 0;
                        break;

                    case ChannelSelect.TOUCHSCREEN_Z2:
                        // log_touchscreen("tried to read touchscreen z2");
                        result = 0;
                        break;
                    
                    case ChannelSelect.TOUCHSCREEN_X:
                        result = input.keys[22] ? 0 : (x_position * (0xa0 - 0x20)) / 256;
                        // log_touchscreen("tried to read touchscreen pos x: %x", result);
                        break;
                    
                    case ChannelSelect.AUX_INPUT:
                        // log_touchscreen("tried to read mic (auxinput)");
                        result = 0;
                        break;
                    
                    case ChannelSelect.TEMPERATURE_1:
                        // log_touchscreen("tried to read temperature 1");
                        result = 0x384;
                        break;
                }

                // result is encoded as a 12 bit value (ConversionMode.BIT_12).
                // so we convert to an 8 bit value by rightshifting by 4.
                if (conversion_mode == ConversionMode.BIT_8) {
                    result >>= 4;
                }

                break;
        }

        return result;
    }

    override void chipselect_fall() {
        state = State.WAITING_FOR_COMMAND;
    }

    override void chipselect_rise() {
        state = State.WAITING_FOR_CHIPSELECT;
    }

    void update_touchscreen_position(int x_position, int y_position) {
        this.x_position = x_position;
        this.y_position = y_position;
    }
}