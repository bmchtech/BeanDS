module emu.hw.spi.spi;

import util;

__gshared SPI spi;
final class SPI {
    private this() {

    }

    void reset() {
        spi = new SPI();
    }

    Byte read_SPICNT(int target_byte) {
        return Byte(0);
    }

    void write_SPICNT(int target_byte, Byte data) {

    }

    T read_SPIDATA(T)() {
        return T(0);
    }

    void write_SPIDATA(T)(T data) {

    }
}