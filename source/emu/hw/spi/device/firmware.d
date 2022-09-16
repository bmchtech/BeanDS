module emu.hw.spi.device.firmware;

import emu;
import util;

enum FirmwareLanguage {
    JAPANESE = 0,
    ENGLISH  = 1,
    FRENCH   = 2,
    GERMAN   = 3,
    ITALIAN  = 4,
    SPANISH  = 5,
    CHINESE  = 6,
    KOREAN   = 7
}

struct UserSettings {
    Byte scr_x1;
    Byte scr_x2;
    Byte scr_y1;
    Byte scr_y2;
    Half adc_x1;
    Half adc_x2;
    Half adc_y1;
    Half adc_y2;

    // TODO: add all the other user settings here
    //       but im lazy to maybe later

    static UserSettings get_default() {
        return UserSettings(
            Byte(0x20),
            Byte(0xE0),
            Byte(0x20),
            Byte(0xA0),
            Half(0x02DF),
            Half(0x0D3B),
            Half(0x032C),
            Half(0x0CE7)
        );
    }
}

__gshared Firmware firmware;
final class Firmware : SPIDevice {

    enum FIRMWARE_SIZE = 0x40000;
    
    enum State {
        WAITING_FOR_CHIPSELECT = 0,
        WAITING_FOR_COMMAND,
        CALCULATING_COMMAND_RESPONSE
    }

    enum Command {
        ReadJEDECIdentification,
        ReadStatusRegister,
        ReadData,
        ReadDataFast,
        PageWrite,
        PageProgram,
        PageErase,
        SectorErase,
    }
    
    State state;
    Command command;

    UserSettings user_settings;

    bool write_enable;
    bool power_on;

    int access_number;

    Byte[0x1000000] data;
    Word address;

    this() {
        state = State.WAITING_FOR_CHIPSELECT;
        firmware = this;

        user_settings = UserSettings.get_default();
    }

    void direct_boot() {
        power_on = true;
    }

    void load_firmware(Byte[] data) {
        this.data[0..FIRMWARE_SIZE] = data[0..FIRMWARE_SIZE];

        user_settings.adc_x1 = data.read!Half(0x3FE58);
        user_settings.adc_y1 = data.read!Half(0x3FE5A);
        user_settings.scr_x1 = data.read!Byte(0x3FE5C);
        user_settings.scr_y1 = data.read!Byte(0x3FE5D);
        user_settings.adc_x2 = data.read!Half(0x3FE5E);
        user_settings.adc_y2 = data.read!Half(0x3FE60);
        user_settings.scr_x2 = data.read!Byte(0x3FE62);
        user_settings.scr_y2 = data.read!Byte(0x3FE63);

        touchscreen.recalibrate();
    }

    override Byte write(Byte b) {
        // arm7.num_log = 20000;
        Byte value = 0;

        final switch (state) {
            case State.WAITING_FOR_CHIPSELECT:
                break;
            
            case State.WAITING_FOR_COMMAND:
                if (parse_command(b)) {
                    access_number = 0;
                    state = State.CALCULATING_COMMAND_RESPONSE;
                } else {
                    state = State.WAITING_FOR_CHIPSELECT;
                }
                break;
            
            case State.CALCULATING_COMMAND_RESPONSE:
                value = calculate_command_response(b);
                access_number++;
                break;
        }

        return value;
    }

    override void chipselect_fall() {
        state = State.WAITING_FOR_COMMAND;
    }

    override void chipselect_rise() {
        state = State.WAITING_FOR_CHIPSELECT;
    }

    Half calculate_command_response(Byte b) {
        switch (command) {
            case Command.ReadJEDECIdentification:
                if (access_number > 3) access_number -= 3;

                switch (access_number) {
                    case 0: return Half(0x20);
                    case 1: return Half(0x40);
                    case 2: return Half(0x12);

                    default:
                        error_firmware("this is an unreachable state, something really went wrong");
                        return Half(0);
                }
            
            case Command.ReadStatusRegister:
                Half value = Half(0);
                value[0] = false; // busy bit, tie this down to 0 because its probably not that useful to emulate
                value[1] = write_enable;
                return value;
            
            case Command.ReadData:
                if (access_number < 3) {
                    // 3 - access_number because address is set in MSB -> LSB order
                    address.set_byte(2 - access_number, b);
                    return Half(0);
                } else {
                    if (address >= data.length) error_firmware("tried to read out of bounds: %x", address);
                    Half value = Half(data[address]);
                    address++;
                    return value;
                }
            
            case Command.ReadDataFast:
                if (access_number < 3) {
                    // 3 - access_number because address is set in MSB -> LSB order
                    address.set_byte(2 - access_number, b);
                    return Half(0);
                } else if (access_number < 4) {
                    // fast access wastes an access here for some reason
                    return Half(0);
                } else {
                    if (address >= data.length) error_firmware("tried to read out of bounds: %x", address);
                    Half value = Half(data[address]);
                    address++;
                    return value;
                }
            
            case Command.PageWrite:
                // TODO: im not sure this is actually how this command works but
                //       i hope it's right? check this

                if (access_number < 3) {
                    // 3 - access_number because address is set in MSB -> LSB order
                    address.set_byte(2 - access_number, b);
                    return Half(0);
                } else if (access_number < 259) {
                    if (address >= data.length) error_firmware("tried to read out of bounds: %x", address);
                    Half value = Half(data[address]);
                    data[address] = b;
                    address++;

                    if (access_number == 258) state = State.WAITING_FOR_CHIPSELECT;
                    return value;
                } else {
                    return Half(0);
                }
            
            // case Command.PageProgram:

            // yknow what ill do the rest of the commands later
            default:
                return Half(0);

        }
    }

    // returns true if this command does further calculation past this write
    // (i.e. if it takes more arguments later)
    private bool parse_command(Byte b) {
        // log_firmware("parsing cmd! %x", b);
        switch (b) {
            case 0x06: write_enable = true;                        return false;
            case 0x04: write_enable = false;                       return false;
            case 0xB9: power_on     = false;                       return false;
            case 0xAB: power_on     = true;                        return false;

            case 0x9F: command = Command.ReadJEDECIdentification;  return true;
            case 0x05: command = Command.ReadStatusRegister;       return true;
            case 0x03: command = Command.ReadData;                 return true;
            case 0x0B: command = Command.ReadDataFast;             return true;
            case 0x0A: command = Command.PageWrite;                return true;
            case 0x02: command = Command.PageProgram;              return true;
            case 0xDB: command = Command.PageErase;                return true;
            case 0xD8: command = Command.SectorErase;              return true;

            default: error_eeprom("invalid eeprom command dummy"); return false;
        }
    }
}