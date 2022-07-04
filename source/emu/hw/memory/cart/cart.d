module emu.hw.memory.cart.cart;

import core.bitop;
import core.stdc.string;

import emu;
import util;

__gshared Cart cart;
final class Cart {
    CartHeader* cart_header;
    Byte[] rom;

    this(Byte[] rom) {
        cart = this;
        this.rom = new Byte[rom.length];
        this.rom[0..rom.length] = rom[0..rom.length];
        
        this.cart_header = get_cart_header(rom);
    }

    void direct_boot() {
    }

    @property 
    size_t rom_size() {
        return rom.length;
    }

    Pixel[32][32] get_icon() {
        Word icon_offset = this.cart_header.icon_offset;
        Pixel[32][32] icon_texture;

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

                icon_texture[x][y] = Pixel(rom.read!Half(icon_offset + 0x220 + palette_entry * 2));
            }
            }
        }
        
        return icon_texture;
    }

    char[128] rom_title_buf;
    string get_rom_title(FirmwareLanguage language) {
        import std.utf;
            
        Word icon_offset = this.cart_header.icon_offset;

        if (icon_offset != 0) {
            Word rom_title_address = icon_offset + 0x240 + cast(int) language * 0x100;
            wstring rom_title_utf16 = cast(wstring) (cast(char[]) rom[rom_title_address .. rom_title_address + 0x100]);
            
            size_t i = 0;
            size_t j = 0;

            while (i < 128) {
                rom_title_buf[j] = cast(char) rom_title_utf16.decode(i);
                j++;
            }
        }

        return cast(string) rom_title_buf;
    }

    T read(T)(Word address, HwType hw_type) {
        if (slot.access_rights != hw_type) { 
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

    Byte read_ROMCTRL(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0: break;
            case 1: break;
            case 2: 
                result[7]    = transfer_ongoing; // next data word is always ready
                break;

            case 3: 
                result[0..2] = data_block_size_index;
                result[7]    = transfer_ongoing;
                break;
        }

        return result;
    }

    void write_ROMCTRL(int target_byte, Byte value) {
        if (target_byte == 3) transfer_ongoing = value[7];

        if (transfer_ongoing) start_transfer();
    }

    void write_ROMDATAOUT(int target_byte, Byte value) {
        command &= ~((cast(u64) 0xFF)  << cast(u64) (target_byte * 8));
        command |=  ((cast(u64) value) << cast(u64) (target_byte * 8));
    }

    T read_ROMRESULT(T)(int offset) {
        if (!transfer_ongoing) error_cart("tried to read from ROMRESULT when no transfer was ongoing");

        T result = cast(T) outbuffer[outbuffer_index];
        outbuffer_index++;
        // log_cart("reading from romresult: %x, %d / %d", result, outbuffer_index, outbuffer_length);

        if (outbuffer_index == outbuffer_length) {
            transfer_ongoing = false;
            // log_cart("transfer ended!");
            if (auxspi.transfer_completion_irq7_enable) interrupt7.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION);
            if (auxspi.transfer_completion_irq9_enable) interrupt9.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION);
        }

        return cast(T) (result >> (8 * offset));
    }

    int get_data_block_size(int default_size) {
        if (data_block_size_index == 0) return default_size;
        if (data_block_size_index == 7) return 4;
        return 0x100 << data_block_size_index;
    }

    void start_transfer() {
        // log_cart("Starting a transfer with command %x, %x", command, arm9.regs[pc]);
        
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
            if (address + length >= rom_size()) error_cart("Tried to initiate a B7 transfer at an out of bounds region!");
            
            memcpy(&outbuffer, &rom[address], length);
            // log_cart("memcpy of addr %x %x %x %x", bswap((command >> 8) & 0xFFFF_FFFF), ((command >> 8) & 0xFFFF_FFFF), address, command >> 8);
            outbuffer_length = length / 4;
        } else

        if ((command & 0xFF) == 0xB8) {
            auto length = get_data_block_size(4);

            for (int i = 0; i < length / 4; i++) {
                outbuffer[i] = get_cart_id();
            }

            // log_cart("getting cart id");

            outbuffer_length = length / 4;
        } else

        error_cart("tried to issue an invalid cart command: %x", command);
        
        outbuffer_index  = 0;

        DMA_maybe_start_cart_transfer();
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
}