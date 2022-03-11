module core.hw.memory.cartridge.cartridge;

import core.hw.memory.cartridge;
import util;

struct Cartridge {
    CartridgeHeader* cartridge_header;
    Byte[] rom;


    this(Byte[] rom) {
        this.rom = rom;
        this.cartridge_header = get_cartridge_header(rom);
    }
}