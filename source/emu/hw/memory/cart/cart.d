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
        main_memory.write!Word(Word(0x7FF800), get_cart_id());
        main_memory.write!Word(Word(0x7FF804), get_cart_id());
        main_memory.write!Word(Word(0x7FFC00), get_cart_id());
        main_memory.write!Word(Word(0x7FFC04), get_cart_id());
        main_memory.write!Word(Word(0x7FFC3C), Word(0x00000332));
        main_memory.write!Word(Word(0x7FFC40), Word(1)); // boot flag

        // obtained from the no$gba emulator
        main_memory.write!Half(Word(0x7FFCD8), Half(0x02DF));
        main_memory.write!Half(Word(0x7FFCDA), Half(0x032C));
        main_memory.write!Half(Word(0x7FFCDC), Half(0x2020));
        main_memory.write!Half(Word(0x7FFCDE), Half(0x0D3B));
        main_memory.write!Half(Word(0x7FFCE0), Half(0x0CE7));
        main_memory.write!Half(Word(0x7FFCE2), Half(0xA0E0));
    }

    @property 
    size_t rom_size() {
        return rom.length;
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
        }

        return cast(T) (result >> (8 * offset));
    }

    int get_data_block_size(int default_size) {
        if (data_block_size_index == 0) return default_size;
        if (data_block_size_index == 7) return 4;
        return 0x100 << data_block_size_index;
    }

    void start_transfer() {
        // log_cart("Starting a transfer with command %x", command);
        
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

            outbuffer_length = length / 4;
        } else

        error_cart("tried to issue an invalid cart command: %x", command);
        
        outbuffer_index  = 0;
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