module emu.hw.spi.device.touchscreen;

import emu;
import util;

final class TouchScreen : SPIDevice {
    this() {}

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

    PowerDownMode   power_down_mode;
    ReferenceSelect reference_select;
    ConversionMode  conversion_mode;
    ChannelSelect   channel_select;

    override void write(Byte b) {
        // bit 7 must be set in order for this command to be valid
        // it's the first bit thats received on the SPI bus (which
        // im not emulating bit by bit). and the first bit must be 1,
        // so we check that bit 7 here is 1 before continuing.
        if (!b[7]) {
            log_touchscreen("received malformed touchscreen command: %x %x", b, arm7.regs[pc]);
            return;
        }

        power_down_mode  = cast(PowerDownMode)   b[0..1];
        reference_select = cast(ReferenceSelect) b[2];
        conversion_mode  = cast(ConversionMode)  b[3];
        channel_select   = cast(ChannelSelect)   b[4..6];

        log_touchscreen("received the sussy baka: %x", b);
    }

    override Half read() {
        final switch (channel_select) {
            case ChannelSelect.TEMPERATURE_0:
                log_touchscreen("tried to read temperature 0");
                return Half(0);
            
            case ChannelSelect.TOUCHSCREEN_Y:
                log_touchscreen("tried to read touchscreen y");
                return Half(0xFFF);
            
            case ChannelSelect.BATTERY_VOLTAGE:
                return Half(0);

            case ChannelSelect.TOUCHSCREEN_Z1:
                log_touchscreen("tried to read touchscreen z1");
                return Half(0);

            case ChannelSelect.TOUCHSCREEN_Z2:
                log_touchscreen("tried to read touchscreen z2");
                return Half(0);
            
            case ChannelSelect.TOUCHSCREEN_X:
                log_touchscreen("tried to read touchscreen x");
                return Half(0);
            
            case ChannelSelect.AUX_INPUT:
                log_touchscreen("tried to read mic (auxinput)");
                return Half(0);
            
            case ChannelSelect.TEMPERATURE_1:
                log_touchscreen("tried to read temperature 1");
                return Half(0);
        }
    }
}