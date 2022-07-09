module emu.hw.misc.rtc;

import std.datetime;

import emu;
import util;

struct RTCParams {
    bool SCK;
    bool SIO;
    bool CS;
}

__gshared RTCHook rtc_hook;
final class RTCHook {
    alias RTCImpl = RTC_S_35199A01;

    RTCImpl rtc;

    bool data_direction;

    this() {
        rtc = new RTCImpl();
    }

    void reset() {
        data_direction = false;
        rtc.reset();
    }

    void write_RTC(int target_byte, Byte value) {
        // log_rtc("arm7: %x", arm7.regs[pc]);
        // TODO: do i need to implement the data direction bit?
        // idk but ill preserve its value anyway
        data_direction = value[3];

        rtc.write(
            RTCParams(
                value[1],
                value[0],
                value[2]
            )
        );
    }

    Byte read_RTC(int target_byte) {
        auto rtc_params = rtc.read();

        Byte value = 0;
        value[0] = rtc_params.SIO;
        value[1] = rtc_params.SCK;
        value[2] = rtc_params.CS;
        value[3] = data_direction;
        return value;
    }
}

final class RTC_S_35199A01 {
    bool SCK;
    bool SIO;
    bool CS;

    ubyte serial_data;
    int   serial_index;

    ubyte* active_register;
    ubyte  status_register_1;
    ubyte  status_register_2;
    ubyte  date_time_year;
    ubyte  date_time_month;
    ubyte  date_time_day;
    ubyte  date_time_day_of_week;
    ubyte  date_time_hh;
    ubyte  date_time_mm;
    ubyte  date_time_ss;

    int current_command_index;
    int current_register_index;

    enum State {
        WAITING_FOR_COMMAND,
        RECEIVING_COMMAND,
        READING_PARAMETERS,
        WRITING_REGISTER
    }

    struct CommandData {
        ubyte*[] registers;
    }
    
    CommandData[] commands;

    State state;

    this() {
        commands = [
            CommandData([&status_register_1]),
            CommandData([&status_register_2]),
            CommandData([&date_time_year,
                         &date_time_month,
                         &date_time_day,
                         &date_time_day_of_week,
                         &date_time_hh,
                         &date_time_mm,
                         &date_time_ss]),
            CommandData([&date_time_hh,
                         &date_time_mm,
                         &date_time_ss]),
            CommandData([]),
            CommandData([]),
            CommandData([]),
            CommandData([]),
        ];
    }

    void write(RTCParams rtc_params) {
        bool old_SCK = this.SCK;
        bool old_SIO = this.SIO;
        bool old_CS  = this.CS;

        SCK = rtc_params.SCK;
        SIO = rtc_params.SIO;
        CS  = rtc_params.CS;
    
        if (rising_edge(old_CS, CS)) {
            this.state = State.RECEIVING_COMMAND;
        }

        if (falling_edge(old_CS, CS)) {
            this.state = State.WAITING_FOR_COMMAND;
        }

        if (rising_edge(old_SCK, SCK) && state != State.WAITING_FOR_COMMAND) {
            
            switch (state) {
                case State.READING_PARAMETERS:
                    SIO = bit(*this.get_active_register(), this.serial_index); 
                    serial_index++;

                    if (this.serial_index == 8) {
                        this.serial_index = 0; 
                        advance_current_register_value();
                    }
                    
                    break;

                case State.WRITING_REGISTER:
                    auto old_value = *this.get_active_register();
                    old_value &= ~(1 << this.serial_index);
                    old_value |= (SIO << this.serial_index);

                    *this.get_active_register() = old_value; 
                    serial_index++;

                    if (this.serial_index == 8) {
                        this.serial_index = 0; 
                        advance_current_register_value();
                    }

                    break;
                case State.RECEIVING_COMMAND:
                    this.serial_data |= (SIO << this.serial_index);
                    serial_index++;

                    // last serial transfer?
                    if (this.serial_index == 8) {
                        this.serial_index = 0;

                        if (!is_command(this.serial_data)) {
                            import core.bitop;
                            this.serial_data = bitswap((cast(uint) this.serial_data) << 24) & 0xFF;
                        }

                        this.state = bit(this.serial_data, 0) ?
                            State.READING_PARAMETERS :
                            State.WRITING_REGISTER;

                        auto command = bits(this.serial_data, 1, 3);
                        handle_command(command);
                        this.serial_data = 0;
                    }
                    break;
                default: break;
            }
        }
    }

    ubyte to_bcd(int input) {
        // assumes 2 digits in input
        auto digit_1 = input / 10;
        auto digit_2 = input % 10;
        return cast(ubyte) ((digit_1 << 4) | digit_2);
    }

    bool is_command(ubyte data) {
        return bits(data, 4, 7) == 6;
    }

    void advance_current_register_value() {
        auto current_command = commands[current_command_index];

        if (current_register_index + 1 >= current_command.registers.length) {
            current_register_index = 0;
            state = State.WAITING_FOR_COMMAND;
            return;
        }

        auto next_register = current_command.registers[current_register_index + 1];

        set_active_register_value(next_register);
        current_register_index++;
    }

    void set_active_register_value(ubyte* register) {
        this.active_register = register;
    }

    ubyte* get_active_register() {
        return this.active_register;
    }

    void handle_command(int command) {
        switch (command) {
            case 0: reset(); break;

            default:
                reset_time();
                this.current_command_index  = command;
                this.current_register_index = 0;
                if (commands[command].registers.length == 0) {
                    log_rtc("Command %x not implemented", command);
                } else {
                    log_rtc("Command %x received", command);
                    // arm9.num_log = 100000000;
                    set_active_register_value(commands[command].registers[0]);
                }
        }
    }

    void reset_time() {
        auto st = Clock.currTime();
        this.date_time_year        = to_bcd(st.year - 2000);
        this.date_time_month       = to_bcd(st.month);
        this.date_time_day         = to_bcd(st.day);
        this.date_time_day_of_week = to_bcd(st.dayOfWeek);
        this.date_time_hh          = to_bcd(st.hour);
        this.date_time_mm          = to_bcd(st.minute);
        this.date_time_ss          = to_bcd(st.second);
    }

    void reset() {
        log_rtc("reset");

        state = State.WAITING_FOR_COMMAND;

        this.SCK = false;
        this.SIO = false;
        this.CS  = false;

        this.serial_data  = 0;
        this.serial_index = 0;

        this.current_command_index  = 0;
        this.current_register_index = 0;
        
        reset_time();

        set_active_register_value(&status_register_2);
        status_register_2 = 0;
    }

    RTCParams read() {
        return RTCParams(
            SCK,
            SIO,
            CS
        );
    }
}