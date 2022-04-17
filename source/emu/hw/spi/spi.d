module emu.hw.spi.spi;

import emu;
import util;

__gshared SPI spi;
final class SPI {
    enum SPIDevice {
        FIRMWARE    = 0,
        TOUCHSCREEN = 1,
        POWERMAN    = 2,
        INVALID     = 3
    }

    int baudrate; // we don't really care about you but we need to save your value anyway
    SPIDevice device;
    bool busy;
    bool transfer_size; // 0 = 8bit, 1 = 16bit. tho its bugged and unused on the DS so we don't care about it either
    bool chipselect_hold;
    bool irq_enable;
    bool bus_enable;

    // SPIDevice[3] spi_devices;

    private this() {
        // spi_devices = [

        // ]
    }

    static void reset() {
        spi = new SPI();
    }

    Byte read_SPICNT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0..1] = baudrate;
                result[7]    = false;
                break;
            
            case 1:
                result[0..1] = device;
                result[2]    = transfer_size;
                result[3]    = chipselect_hold;
                result[6]    = irq_enable;
                result[7]    = bus_enable;
                break;
        }

        return result;
    }

    void write_SPICNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                baudrate = data[0..1];
                break;
            
            case 1:
                device          = cast(SPIDevice) data[0..1];
                transfer_size   = data[2];
                chipselect_hold = data[3];
                irq_enable      = data[6];
                bus_enable      = data[7];
                break;
        }
    }

    T read_SPIDATA(T)() {
        if (device == SPIDevice.INVALID) {
            error_spi("Tried to write to an invalid SPI device!");
        }

        if (device != SPIDevice.POWERMAN) {
            log_spi("Tried to write to an unimplemented SPI device: %d!", device);
            return T(0);
        }

        return T(0);
        // return cast(Byte) spi_devices[device].read(data);
    }

    void write_SPIDATA(T)(T data) {
        if (!bus_enable) return;
        
        if (!busy) {
            busy = true;
            return;
        }

        if (!chipselect_hold) {
            busy = false;
        }

        // spi_devices[device].write(cast(Byte) data);
    }
}