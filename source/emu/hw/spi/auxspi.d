module emu.hw.spi.auxspi;

import emu;
import util;

__gshared AUXSPI auxspi;

final class AUXSPI {
    EEPROM!(32, 256) eeprom;

    private this () {
        eeprom = new EEPROM!(32, 256);
    }

    static void reset() {
        auxspi = new AUXSPI();
    }

    bool transfer_completion_irq7_enable;
    bool transfer_completion_irq9_enable;
    bool spi_hold_chipselect;
    bool nds_slot_mode;
    bool nds_slot_enable;
    bool active = false;
    int baudrate;

    Byte result;

    Byte read_AUXSPICNT7(int target_byte) {
        Byte result;
        result |= read_AUXSPICNT(target_byte);
        
        if (target_byte == 1) result[6] = transfer_completion_irq7_enable;
        return result;
    }

    Byte read_AUXSPICNT9(int target_byte) {
        Byte result;
        result |= read_AUXSPICNT(target_byte);
        
        if (target_byte == 1) result[6] = transfer_completion_irq9_enable;
        return result;
    }

    Byte read_AUXSPICNT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0..1] = baudrate;
                result[6]    = spi_hold_chipselect;
                result[7]    = false; // ig we'll tie the busy bit down
                break;

            case 1:
                result[5] = nds_slot_mode;
                result[7] = nds_slot_enable;        
                break;
        }

        return result;
    }

    void write_AUXSPICNT7(int target_byte, Byte data) {
        if (target_byte == 1) transfer_completion_irq7_enable = data[6];
        write_AUXSPICNT(target_byte, data);
    }

    void write_AUXSPICNT9(int target_byte, Byte data) {
        if (target_byte == 1) transfer_completion_irq9_enable = data[6];
        write_AUXSPICNT(target_byte, data);
    }

    private void write_AUXSPICNT(int target_byte, Byte data) {
        log_auxspi("AUXSPICNT: %x %x", target_byte, data);
        final switch (target_byte) {
            case 0:
                if ( data[6] && !spi_hold_chipselect) eeprom.chipselect_fall();
                // if (!data[6] &&  spi_hold_chipselect) eeprom.chipselect_rise();

                baudrate            = data[0..1];
                spi_hold_chipselect = data[6];
                break;

            case 1:
                nds_slot_mode   = data[5];
                nds_slot_enable = data[7];
        }
    }

    void write_AUXSPIDATA7(int target_byte, Byte data) {
        if (!nds_slot_mode) return;

        if (target_byte == 0) {
            result = eeprom.write(data);
            if (!spi_hold_chipselect) eeprom.chipselect_fall();
            active = false;
        }

        active = true;
    }

    void write_AUXSPIDATA9(int target_byte, Byte data) {
        if (!nds_slot_mode) return;

        if (target_byte == 0) {
            result = eeprom.write(data);
            if (!spi_hold_chipselect) eeprom.chipselect_fall();
            active = false;
        }

        active = true;
    }

    Byte read_AUXSPIDATA7(int target_byte) {
        if (!nds_slot_mode) return Byte(0);

        if (target_byte == 0) {
            active = false;
            return result;
        }

        return Byte(0);
    }

    Byte read_AUXSPIDATA9(int target_byte) {
        if (!nds_slot_mode) return Byte(0);

        if (target_byte == 0) {
            active = false;
            return result;
        }

        return Byte(0);
    }
}