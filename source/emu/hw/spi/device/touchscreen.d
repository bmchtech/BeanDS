module emu.hw.spi.device.touchscreen;

import emu;
import util;

__gshared TouchScreen touchscreen;
final class TouchScreen : SPIDevice {
    this() {
        touchscreen = this;
        state = State.WAITING_FOR_CHIPSELECT;
    }

    void direct_boot() {
        scr_x1 = firmware.user_settings.scr_x1;
        scr_x2 = firmware.user_settings.scr_x2;
        scr_y1 = firmware.user_settings.scr_y1;
        scr_y2 = firmware.user_settings.scr_y2;
        adc_x1 = firmware.user_settings.adc_x1;
        adc_x2 = firmware.user_settings.adc_x2;
        adc_y1 = firmware.user_settings.adc_y1;
        adc_y2 = firmware.user_settings.adc_y2;
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
        WAITING_FOR_CHIPSELECT
    }

    State state;

    PowerDownMode   power_down_mode;
    ReferenceSelect reference_select;
    ConversionMode  conversion_mode;
    ChannelSelect   channel_select;

    int x_position;
    int y_position;
    bool pen_down;

    Byte scr_x1;
    Byte scr_x2;
    Byte scr_y1;
    Byte scr_y2;
    Half adc_x1;
    Half adc_x2;
    Half adc_y1;
    Half adc_y2;

    Byte[2] result;
    int transferring = 0;

    void set_result(int incoming_result) {
        // this took me a while to understand to let me explain:
        // data is output as follows:
        // - one 0 bit
        // - the data, MSB first
        // since the NDS abstracts this serial bit transfer stuff
        // and makes it appear as if 8 bits are transferred at a
        // time, i have to store the result in a Byte array. the
        // reason i use leftshifts by 7 and 3 instead of 8 and 4
        // is because of the leading 0 bit.
        if (conversion_mode == ConversionMode.BIT_8) {
            incoming_result <<= 7;
        } else {
            incoming_result <<= 3;
        }

        this.result[0] = Byte((incoming_result >> 8) & 0xFF);
        this.result[1] = Byte((incoming_result >> 0) & 0xFF);
    }
    
    bool sussine = true;

    override Byte write(Byte b) {
        // log_touchscreen("write: %x", b);
        
        Byte return_value = result[0];
        result[0] = result[1];

        if (b[7]) {
            final switch (state) {
                case State.WAITING_FOR_COMMAND:
                    power_down_mode  = cast(PowerDownMode)   b[0..1];
                    reference_select = cast(ReferenceSelect) b[2];
                    conversion_mode  = cast(ConversionMode)  b[3];
                    channel_select   = cast(ChannelSelect)   b[4..6];

                    final switch (channel_select) {
                        case ChannelSelect.TEMPERATURE_0:
                            // log_touchscreen("tried to read temperature 0");
                            set_result(0x2F8);
                            break;
                        
                        case ChannelSelect.TOUCHSCREEN_Y:
                            if ((scr_y2 - scr_y1) == 0) set_result(0);
                                else {
                                set_result( 
                                    input.keys[22] ? 
                                    0 : 
                                    ((y_position + 1 - scr_y1) * (adc_y2 - adc_y1)) / (scr_y2 - scr_y1) + adc_y1
                                );
                            }

                            if (sussine) {
                                IFTDebugger.start_debugging();
                                scheduler.add_event_relative_to_clock(() => IFTDebugger.stop_debugging(), 100);
                            }
                            
                            sussine = false;
                            // log_touchscreen("tried to read touchscreen pos y: %x %x %x %x %x %x", 0x1F, scr_y1, scr_y2, adc_y1, adc_y2, input.keys[22] ? 
                            //     0 : 
                            //     ((y_position + 1 - scr_y1) * (adc_y2 - adc_y1)) / (scr_y2 - scr_y1) + adc_y1);
                            break;
                        
                        case ChannelSelect.BATTERY_VOLTAGE:
                            set_result(0);
                            break;

                        case ChannelSelect.TOUCHSCREEN_Z1:
                            // log_touchscreen("tried to read touchscreen z1");
                            set_result(0);
                            break;

                        case ChannelSelect.TOUCHSCREEN_Z2:
                            // log_touchscreen("tried to read touchscreen z2");
                            set_result(0);
                            break;
                        
                        case ChannelSelect.TOUCHSCREEN_X:
                            if ((scr_x2 - scr_x1) == 0) set_result(0);
                            else {
                                set_result( 
                                    input.keys[22] ? 
                                    0 : 
                                    ((x_position + 1 - scr_x1) * (adc_x2 - adc_x1)) / (scr_x2 - scr_x1) + adc_x1
                                );
                            }
                            // log_touchscreen("tried to read touchscreen pos x: %x %x", 
                            //     input.keys[22] ? 
                            //     0 : 
                            //     ((x_position + 1 - scr_x1) * (adc_x2 - adc_x1)) / (scr_x2 - scr_x1) + adc_x1, arm7.regs[pc]);
                            break;
                        
                        case ChannelSelect.AUX_INPUT:
                            // log_touchscreen("tried to read mic (auxinput)");
                            set_result(0);
                            break;
                        
                        case ChannelSelect.TEMPERATURE_1:
                            // log_touchscreen("tried to read temperature 1");
                            set_result(0x384);
                            break;
                    }

                    break;
                
                case State.WAITING_FOR_CHIPSELECT:
                    break;
            }
        }

        // log_touchscreen("returning %x", return_value);

        return return_value;
    }

    override void chipselect_fall() {
        // log_touchscreen("chipselect fall");
        state = State.WAITING_FOR_COMMAND;
    }

    override void chipselect_rise() {
        // log_touchscreen("chipselect rise");
        state = State.WAITING_FOR_CHIPSELECT;
    }

    void update_touchscreen_position(int x_position, int y_position) {
        this.x_position = x_position;
        this.y_position = y_position;
    }
}