module emu.hw.spi.device.eeprom;

import emu;
import util;

public class EEPROM(int page_size, int num_pages) : SPIDevice {
    enum total_bytes = page_size * num_pages;

    enum State {
        WAITING_FOR_COMMAND,
        RECEIVING_ARGUMENTS,
        RECEIVING_RESPONSE,
        WRITING_DATA,
        READING_DATA,
        READING_STATUS,
        WRITING_STATUS,
        READING_JEDEC_ID,
        WAITING_FOR_CHIPSELECT
    }
    
    State state;

    bool write_enable_latch;
    bool status_register_write_disable;
    int write_protect;

    Word current_address;
    Word current_page;
    Word current_page_offset;

    int accesses_remaining;

    Byte[total_bytes] data;

    this() {
        state = State.WAITING_FOR_CHIPSELECT;
    }

    override Half write(Byte b) {
        Half result = 0;

        // log_eeprom("received write: %x", b);
        switch (state) {
            case State.WAITING_FOR_COMMAND:
                // log_eeprom("    parsing the command: %x", b);
                parse_command(b);
                break;

            case State.WRITING_STATUS:
                if (!write_enable_latch) break;
                // log_eeprom("    setting status: %x", b);
                write_protect                 = b[2..3];
                status_register_write_disable = b[7];
                break;

            case State.READING_STATUS:
                result[1]    = write_enable_latch;
                result[2..3] = write_protect;
                result[7]    = status_register_write_disable;
                // log_eeprom("    reading status: %x", result);
                break;

            case State.READING_JEDEC_ID:
                result = 0xFF;
                // log_eeprom("    reading jedec id");
                break;
            
            // bad code
            case State.READING_DATA:
                if (!write_enable_latch) break;
                // log_eeprom("    address write? (write): %x", b);
                handle_address_write(b);
                
                if (accesses_remaining <= page_size) {
                    // if (current_page >= num_pages) error_eeprom("tried to read from an invalid eeprom page: %x", current_page);
                    result = data[current_address];
                    // log_eeprom("    reading data from %x %x %x", current_address, result, arm7.regs[pc]);
                    current_address++;
                    current_address %= total_bytes;
                } else {                
                    // log_eeprom("    handling address write: %x, %x, %x", current_page, page_size - accesses_remaining, b);
                    handle_address_write(b);
                    accesses_remaining--;
                }
                break;
            
            case State.WRITING_DATA:
                if (!write_enable_latch) break;
                // log_eeprom("    address write? (write): %x", b);
                handle_address_write(b);
                
                if (accesses_remaining <= page_size) {
                    if (current_page >= num_pages) error_eeprom("tried to read from an invalid eeprom page: %x", current_page);
                    data[current_address] = b;
                    // log_eeprom("    writing data to page %x, %x %x", current_address, 69, b);
                    current_address++;
                    current_address %= total_bytes;
                } else {                
                    // log_eeprom("    handling address write: %x, %x, %x", current_page, page_size - accesses_remaining, b);
                    handle_address_write(b);
                    accesses_remaining--;
                }

                break;
            
            default: break;
        }

        return result;
    }

    void handle_address_write(Byte b) {
        if (accesses_remaining == page_size + 2) {
            current_address[8..15] = b;
        }

        if (accesses_remaining == page_size + 1) {
            current_address[0..7] = b;
            current_page        = current_address / page_size;
            current_page_offset = current_address % page_size;
        }
    }

    override void chipselect_rise() {
        state = State.WAITING_FOR_COMMAND;
    }

    override void chipselect_fall() {
        if (state == State.WRITING_DATA || state == State.WRITING_STATUS) {
            write_enable_latch = false;
        }
        // log_eeprom("resetti");
    }

    private void parse_command(Byte b) {
        switch (b) {
            case 0x05: state = State.READING_STATUS; break;
            case 0x01: state = state.WRITING_STATUS; break;
            case 0x03: state = State.READING_DATA; accesses_remaining = page_size + 2; break;
            case 0x02: state = State.WRITING_DATA; accesses_remaining = page_size + 2; break;
            case 0x9F: state = State.READING_JEDEC_ID; break;
            case 0x06: write_enable_latch = true;  break;
            case 0x04: write_enable_latch = false; break;
            default: error_eeprom("invalid eeprom command dummy");
        }
    }
}