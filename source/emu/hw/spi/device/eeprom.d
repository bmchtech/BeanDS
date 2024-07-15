module emu.hw.spi.device.eeprom;

import emu.hw.spi.device;
import std.mmfile;
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

    MmFile save_mmfile;

    this() {
        state = State.WAITING_FOR_CHIPSELECT;
    }

    void set_save_mmfile(MmFile save_mmfile) {
        this.save_mmfile = save_mmfile;
        data = cast(Byte[]) save_mmfile[];
    }

    override Byte write(Byte b) {
        Byte result = 0;

        switch (state) {
            case State.WAITING_FOR_COMMAND:
                parse_command(b);
                break;

            case State.WRITING_STATUS:
                if (!write_enable_latch) break;
                write_protect                 = b[2..3];
                status_register_write_disable = b[7];
                break;

            case State.READING_STATUS:
                result[1]    = write_enable_latch;
                result[2..3] = write_protect;
                result[7]    = status_register_write_disable;
                break;

            case State.READING_JEDEC_ID:
                result = 0xFF;
                break;
            
            // bad code
            case State.READING_DATA:
                handle_address_write(b);
                
                if (accesses_remaining <= page_size) {
                    result = data[current_address];
                    current_address++;
                    current_address %= total_bytes;
                } else {                
                    handle_address_write(b);
                    accesses_remaining--;
                }
                break;
            
            case State.WRITING_DATA:
                if (!write_enable_latch) break;
                handle_address_write(b);
                
                if (accesses_remaining <= page_size) {
                    data[current_address] = b;
                    save_mmfile[current_address] = b;

                    current_address++;
                    current_address %= total_bytes;
                } else {                
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

    override void chipselect_fall() {
        state = State.WAITING_FOR_COMMAND;
    }

    override void chipselect_rise() {
        state = State.WAITING_FOR_CHIPSELECT;
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
            default: log_eeprom("invalid eeprom command dummy: %x", b);
        }
    }
}