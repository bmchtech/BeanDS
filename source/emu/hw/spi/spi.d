module emu.hw.spi.spi;

import emu.hw.cpu.interrupt;
import emu.hw.spi.device;
import emu.scheduler;
import util;

__gshared SPI spi;
final class SPI {
    int baudrate;
    int selected_device_index;
    SPIDevice selected_device;
    bool busy;
    bool transfer_size; // 0 = 8bit, 1 = 16bit. tho its bugged and unused on the DS so we don't care about it either
    bool chipselect_hold = false;
    bool irq_enable;
    bool bus_enable;
    Half transaction_result;

    SPIDevice[4] spi_devices;

    this() {
        spi_devices = [
            new PowerMan(),
            new Firmware(),
            new TouchScreen(),
            null
        ];
    }

    void reset() {

    }

    Byte read_SPICNT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0..1] = baudrate;
                result[7]    = false;
                break;
            
            case 1:
                result[0..1] = selected_device_index;
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
                if (selected_device_index != data[0..1]) {
                    if (selected_device !is null) selected_device.chipselect_rise();

                    selected_device_index = data[0..1];
                    selected_device = spi_devices[selected_device_index];
                    
                    if (data[3] && selected_device !is null) selected_device.chipselect_fall();
                } else {
                    selected_device_index = data[0..1];
                    selected_device = spi_devices[selected_device_index];

                    if (data[3] && !chipselect_hold) {
                        if (selected_device is null) {
                            error_spi("tried to chipselect an invalid chip");
                        } else {
                            selected_device.chipselect_fall();
                        }
                    }
                }

                transfer_size   = data[2];
                chipselect_hold = data[3];
                irq_enable      = data[6];
                bus_enable      = data[7];

                break;
        }
    }

    T read_SPIDATA(T)(int offset) {
        return T(transaction_result);
    }

    void write_SPIDATA(T)(T data, int offset) {
        if (!bus_enable) return;

        if (selected_device_index == 3) {
            error_spi("Tried to write to an invalid SPI device!");
        }

        if (offset == 0) {
            transaction_result = selected_device.write(Byte(data));
            if (!chipselect_hold) selected_device.chipselect_fall();
        }

        scheduler.add_event_relative_to_clock(
            () => interrupt7.raise_interrupt(Interrupt.SPI_BUS),
            8 << (baudrate)
        );

        if (!chipselect_hold) {
            busy = false;
        }
    }
}