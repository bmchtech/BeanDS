module emu.hw.memory.cart.cart;

import core.bitop;
import core.stdc.string;
import emu.hw.cpu.interrupt;
import emu.hw.hwtype;
import emu.hw.memory.cart.cryptography;
import emu.hw.memory.cart.header;
import emu.hw.memory.dma;
import emu.hw.memory.mem;
import emu.hw.memory.slot;
import emu.hw.spi.auxspi;
import util;

__gshared Cart cart;
final class Cart {
    CartHeader* cart_header;
    Byte[] rom;
    Mode mode;

    Key1Encryption key1_encryption_level2;
    Key1Encryption key1_encryption_level3;

    enum Mode {
        UNENCRYPTED,
        KEY1,
        KEY2,
    }

    this(Byte[] rom) {
        cart = this;
        this.rom = new Byte[rom.length];
        this.rom[0..rom.length] = rom[0..rom.length];
        
        this.cart_header = get_cart_header(rom);

        key1_encryption_level2 = new Key1Encryption();
        key1_encryption_level3 = new Key1Encryption();
    }

    void reset() {
        mode = Mode.UNENCRYPTED;
    }

    void direct_boot() {
        mode = Mode.KEY2;
    }

    @property 
    size_t rom_size() {
        return rom.length;
    }

    import emu.hw.gpu;
    Pixel[32][32] get_icon() {
        Word icon_offset = this.cart_header.icon_offset;
        Pixel[32][32] icon_texture;
        for (int x = 0; x < 32; x++) {
        for (int y = 0; y < 32; y++) {
            icon_texture[y][x] = Pixel(0, 0, 0, 0);
        }
        }

        if (icon_offset != 0) {
            for (int x = 0; x < 32; x++) {
            for (int y = 0; y < 32; y++) {
                int tile_x = x / 8;
                int tile_y = y / 8;

                int fine_x = x % 8;
                int fine_y = y % 8;

                int tile_no = tile_y * 4 + tile_x;
                
                Byte palette_entry = rom.read!Byte(icon_offset + 0x20 + (tile_no * 32 + fine_y * 4 + fine_x / 2));

                if (x & 1) palette_entry >>= 4;
                else       palette_entry &= 0xF;

                Pixel p = Pixel(rom.read!Half(icon_offset + 0x220 + palette_entry * 2));
                if (palette_entry == 0) p.a = 0;
                icon_texture[x][y] = p;
            }
            }
        }
        
        return icon_texture;
    }

    import emu.hw.spi.device.firmware;
    char[128] rom_title_buf;
    string get_rom_title(FirmwareLanguage language) {
        import std.encoding;
        import std.utf;
            
        Word icon_offset = this.cart_header.icon_offset;

        rom_title_buf[0..128] = ' ';

        if (icon_offset != 0) {
            Word rom_title_address = icon_offset + 0x240 + cast(int) language * 0x100;
            wstring rom_title_utf16 = cast(wstring) (cast(char[]) rom[rom_title_address .. rom_title_address + 0x100]);
            
            size_t i = 0;
            size_t j = 0;

            while (i < 128) {
                char[2] result;
                auto len = rom_title_utf16.decode(i).encode!char(result);

                if (result[0] == '\n') break;

                rom_title_buf[j .. j + len] = result[0 .. len];
                j += len;
            }
        }

        return cast(string) rom_title_buf;
    }

    T read(T)(Word address, HwType hw_type) {
        if (slot.nds_slot_access_rights != hw_type) { 
            log_cart("tried to read from cart even though i had no rights!"); 
            return T(0); 
        }

        if (address < rom_size()) {
            return rom.read!T(address);
        }

        error_cart("tried to read from cart at an out of range address: %x", address);
        return T(0);
    }

    bool transfer_ongoing = false;
    u64 command;

    u32[0x100 << 6] outbuffer;
    size_t outbuffer_length = 0;
    int    outbuffer_index  = 0;

    int data_block_size_index;

    int key1_gap1_length;
    int key1_gap2_length;
    int key1_gap_clks;
    int key2_encrypt_data;
    int key2_encrypt_cmd;
    int transfer_clk_rate;
    int resb_release_reset;
    int data_direction;

    private Byte read_ROMCTRL(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0: 
                result[0..7] = key1_gap1_length.bits(0, 7); 
                break;
            case 1: 
                result[0..3] = key1_gap1_length.bits(8, 11);
                result[4]    = key2_encrypt_data;
                break;
            case 2: 
                result[0..5] = key1_gap2_length;
                result[6]    = key2_encrypt_cmd;
                result[7]    = transfer_ongoing; // next data word is always ready
                break;

            case 3: 
                result[0..2] = data_block_size_index;
                result[3]    = transfer_clk_rate;
                result[4]    = key1_gap_clks;
                result[5]    = resb_release_reset;
                result[6]    = data_direction;
                result[7]    = transfer_ongoing;
                break;
        }

        return result;
    }

    private void write_ROMCTRL(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                key1_gap1_length &= ~0xFF;
                key1_gap1_length |= value;
                break;
            case 1:
                key1_gap1_length &= ~0xF00;
                key1_gap1_length |= value << 8;
                key2_encrypt_data = value[4];
                break;
            case 2:
                key1_gap2_length = value[0..5];
                key2_encrypt_cmd = value[6];
                break;
            case 3:
                data_block_size_index = value[0..2];
                transfer_clk_rate     = value[3];
                key1_gap_clks         = value[4];
                resb_release_reset    = value[5];
                data_direction        = value[6];
                transfer_ongoing      = value[7];
        }

        if (transfer_ongoing) start_transfer();
    }

    private void write_ROMDATAOUT(int target_byte, Byte value) {
        command &= ~((cast(u64) 0xFF)  << cast(u64) (target_byte * 8));
        command |=  ((cast(u64) value) << cast(u64) (target_byte * 8));
    }

    private T read_ROMRESULT(T)(int offset) {
        if (!transfer_ongoing) error_cart("tried to read from ROMRESULT when no transfer was ongoing");

        T result = cast(T) outbuffer[outbuffer_index];
        outbuffer_index++;

        if (outbuffer_index == outbuffer_length) {
            transfer_ongoing = false;
            if (auxspi.transfer_completion_irq_enable) interrupt7.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION);
            if (auxspi.transfer_completion_irq_enable) interrupt9.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION);
        }

        return cast(T) (result >> (8 * offset));
    }

    int get_data_block_size(int default_size) {
        if (data_block_size_index == 0) return default_size;
        if (data_block_size_index == 7) return 4;
        return 0x100 << data_block_size_index;
    }

    void start_transfer() {
        final switch (mode) {
            case Mode.UNENCRYPTED: handle_unencrypted_transfer(); break;
            case Mode.KEY1:        handle_key1_transfer();        break;
            case Mode.KEY2:        handle_key2_transfer();        break;
        }
        
        outbuffer_index  = 0;

        dma_maybe_start_cart_transfer();
    }

    void handle_unencrypted_transfer() {
        if ((command & 0xFF) == 0x9F) {
            auto length = get_data_block_size(0x2000);
            memset(&outbuffer, 0xFF, length);
            outbuffer_length = length / 4;
        } else
        
        if ((command & 0xFF) == 0x00) {
            auto length = get_data_block_size(0x200);
            
            if (length >= rom_size()) error_cart("Tried to initiate a 00 (aka cart header) transfer at an out of bounds region!");
            
            memcpy(&outbuffer, &rom[0], length);
            outbuffer_length = length / 4;
        } else

        if ((command & 0xFF) == 0x90) {
            auto length = get_data_block_size(4);

            for (int i = 0; i < length / 4; i++) {
                outbuffer[i] = get_cart_id();
            }

            outbuffer_length = length / 4;
        } else

        if ((command & 0xFF) == 0x3C) {
            auto length = get_data_block_size(0x2000);
            memset(&outbuffer, 0xFF, length);
            outbuffer_length = length / 4;
            mode = Mode.KEY1;
            transfer_ongoing = false;
            this.raise_interrupt();

            key1_encryption_level2.init_keycode(cast(Word) cart_header.game_code, 2, 8);
            key1_encryption_level3.init_keycode(cast(Word) cart_header.game_code, 3, 8);
        } else
        
        error_cart("tried to issue an invalid unencrypted command: %x", command);
    }

    void handle_key1_transfer() {
        u64 swapped = bswap(command);
        key1_encryption_level2.decrypt_64bit(cast(u32*) &swapped);
        u64 decrypted_command = bswap(swapped);

        if ((decrypted_command & 0xF0) == 0x40) {
            auto length = get_data_block_size(0x2000);
            memset(&outbuffer, 0xFF, length);
            outbuffer_length = length / 4;
            transfer_ongoing = false;
            this.raise_interrupt();
        } else

        if ((decrypted_command & 0xF0) == 0x10) {
            auto length = get_data_block_size(4);

            for (int i = 0; i < length / 4; i++) {
                outbuffer[i] = get_cart_id();
            }

            outbuffer_length = length / 4;
        } else

        if ((decrypted_command & 0xF0) == 0x20) {
            auto length = get_data_block_size(0x1000);

            int addr_step = (bswap(decrypted_command) >> 44) & 0xFFFF;
            int addr = addr_step * 0x1000;
            int initial_addr = addr;
            
            int output_offset = 0;

            for (int i = 0; i < 8; i++) {
                if (initial_addr == 0x4000) {
                    for (int j = 0; j < 0x200; j += 8) {
                        u64 scratch = *(cast(u64*) &rom[addr + j]);
                        if (initial_addr == addr && j == 0) {
                            // encryObj - a key that must appear at the beginning of
                            // the secure area block
                            scratch = 0x6A624F7972636E65;
                        }

                        if (addr < 0x4800) {
                            key1_encryption_level3.encrypt_64bit(cast(u32*) &scratch);

                            if (initial_addr == addr && j == 0) {
                                key1_encryption_level2.encrypt_64bit(cast(u32*) &scratch);
                            }
                        }

                        *(cast(u64*) &outbuffer[output_offset / 4]) = scratch;
                        output_offset += 8;
                    }
                } else {
                    for (int j = 0; j < 0x200 / 4; j++) {
                        outbuffer[output_offset / 4] = rom.read!Word(Word(addr + j * 4));
                        output_offset += 4;
                    }
                }

                if (get_cart_id().bit(15)) {
                    error_cart("ill implement this later");
                }

                addr += 0x200;
            }

            outbuffer_length = length / 4;
        } else

        if ((decrypted_command & 0xF0) == 0xA0) {
            auto length = get_data_block_size(0x2000);
            memset(&outbuffer, 0xFF, length);
            outbuffer_length = length / 4;
            mode = Mode.KEY2;
            transfer_ongoing = false;
            this.raise_interrupt();

            key1_encryption_level2.init_keycode(cast(Word) cart_header.game_code, 2, 8);
        } else

        error_cart("tried to issue an invalid KEY1 command: %x", decrypted_command);
    }

    void handle_key2_transfer() {
        if ((command & 0xFF) == 0x9F) {
            auto length = get_data_block_size(0x2000);
            memset(&outbuffer, 0xFF, length);
            outbuffer_length = length / 4;
        } else
        
        if ((command & 0xFF) == 0x00) {
            auto length = get_data_block_size(0x200);
            
            if (length >= rom_size()) error_cart("Tried to initiate a 00 (aka cart header) transfer at an out of bounds region!");
            
            memcpy(&outbuffer, &rom[0], length);
            outbuffer_length = length / 4;
        } else

        if ((command & 0xFF) == 0xB7) {
            // KEY2 data read

            auto length = get_data_block_size(0x200);
            
            Word address = Word(bswap(cast(u32) ((command >> 8) & 0xFFFF_FFFF)));

            if (address < 0x8000) {
                address = 0x8000 + (address & 0x1FF);
            }
            
            if (address + length >= rom_size()) error_cart("Tried to initiate a B7 transfer at an out of bounds region!");
            
            memcpy(&outbuffer, &rom[address], length);
            outbuffer_length = length / 4;
        } else

        if ((command & 0xFF) == 0xB8) {
            auto length = get_data_block_size(4);

            for (int i = 0; i < length / 4; i++) {
                outbuffer[i] = get_cart_id();
            }

            outbuffer_length = length / 4;
        } else
        
        error_cart("tried to issue an invalid KEY2 command: %x", command);
    }

    Word get_cart_id() {
        Word id = 0xC2; // macronix - just pick any manufacturer id it doesnt matter
        // thanks striker! :)
        if (rom_size() >= 1024 * 1024 && rom_size() <= 128 * 1024 * 1024) {
            id.set_byte(1, (rom_size() >> 20) - 1);
        } else {
            id.set_byte(1, 0x100 - (rom_size() >> 28));
        }
        
        return id;
    }

    void raise_interrupt() {
        if (auxspi.transfer_completion_irq_enable) {
            final switch (slot.nds_slot_access_rights) {
                case HwType.NDS7: interrupt7.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION); break;
                case HwType.NDS9: interrupt9.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION); break;
            }
        }
    }

    // these are super repetitive
    // maybe consolidate them with mixins?

    Byte read_ROMCTRL7(int target_byte) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            return read_ROMCTRL(target_byte);
        } else {
            log_cart("NDS7 tried to read from ROMCTRL when it had no rights!");
        }

        return Byte(0);
    }

    Byte read_ROMCTRL9(int target_byte) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            return read_ROMCTRL(target_byte);
        } else {
            log_cart("NDS9 tried to read from ROMCTRL when it had no rights!");
        }

        return Byte(0);
    }

    void write_ROMCTRL7(int target_byte, Byte value) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            write_ROMCTRL(target_byte, value);
        } else {
            log_cart("NDS7 tried to write to ROMCTRL when it had no rights!");
        }
    }

    void write_ROMCTRL9(int target_byte, Byte value) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            write_ROMCTRL(target_byte, value);
        } else {
            log_cart("NDS9 tried to write to ROMCTRL when it had no rights!");
        }
    }

    T read_ROMRESULT7(T)(int offset) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            return read_ROMRESULT!T(offset);
        } else {
            log_cart("NDS7 tried to write to ROMRESULT when it had no rights!");
        }

        return T(0);
    }

    T read_ROMRESULT9(T)(int offset) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            return read_ROMRESULT!T(offset);
        } else {
            log_cart("NDS9 tried to write to ROMRESULT when it had no rights!");
        }

        return T(0);
    }

    void write_ROMDATAOUT7(int target_byte, Byte value) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            write_ROMDATAOUT(target_byte, value);
        } else {
            log_cart("NDS7 tried to write to ROMDATAOUT when it had no rights!");
        }
    }

    void write_ROMDATAOUT9(int target_byte, Byte value) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            write_ROMDATAOUT(target_byte, value);
        } else {
            log_cart("NDS9 tried to write to ROMDATAOUT when it had no rights!");
        }
    }
}