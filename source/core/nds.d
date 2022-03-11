module core.nds;

struct NDS {
    Cart* cart;

    void load_rom(Byte[] rom) {
        cart = new Cart(rom);
    }

    void direct_boot() {
        
    }
}