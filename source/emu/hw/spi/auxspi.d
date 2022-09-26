module emu.hw.spi.auxspi;

import emu;
import util;

__gshared AUXSPI auxspi;

final class AUXSPI {
    EEPROM!(32, 256) eeprom;

    this () {
        eeprom = new EEPROM!(32, 256);
    }

    bool transfer_completion_irq_enable;
    bool spi_hold_chipselect;
    bool nds_slot_mode;
    bool nds_slot_enable;
    bool active = false;
    int baudrate;

    Byte result;

    private Byte read_AUXSPICNT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0..1] = baudrate;
                result[6]    = spi_hold_chipselect;
                result[7]    = false; // ig we'll tie the busy bit down
                break;

            case 1:
                result[5] = nds_slot_mode;
                result[6] = transfer_completion_irq_enable;
                result[7] = nds_slot_enable;        
                break;
        }

        return result;
    }

    private void write_AUXSPICNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                if ( data[6] && !spi_hold_chipselect) eeprom.chipselect_fall();
                // if (!data[6] &&  spi_hold_chipselect) eeprom.chipselect_rise();

                baudrate            = data[0..1];
                spi_hold_chipselect = data[6];
                break;

            case 1:
                nds_slot_mode                  = data[5];
                transfer_completion_irq_enable = data[6];
                nds_slot_enable                = data[7];
        }
    }

    private void write_AUXSPIDATA(int target_byte, Byte data) {
        if (!nds_slot_mode) return;

        if (target_byte == 0) {
            result = eeprom.write(data);
            if (!spi_hold_chipselect) eeprom.chipselect_fall();
            active = false;
        }

        active = true;
    }

    private Byte read_AUXSPIDATA(int target_byte) {
        if (!nds_slot_mode) return Byte(0);

        if (target_byte == 0) {
            active = false;
            return result;
        }

        return Byte(0);
    }

    // stupid accessors

    Byte read_AUXSPICNT7(int target_byte) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            return read_AUXSPICNT(target_byte);
        }

        return Byte(0);
    }

    Byte read_AUXSPICNT9(int target_byte) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            return read_AUXSPICNT(target_byte);
        }

        return Byte(0);
    }

    void write_AUXSPICNT7(int target_byte, Byte data) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            write_AUXSPICNT(target_byte, data);
        }
    }

    void write_AUXSPICNT9(int target_byte, Byte data) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            write_AUXSPICNT(target_byte, data);
        }
    }

    Byte read_AUXSPIDATA7(int target_byte) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            return read_AUXSPIDATA(target_byte);
        }

        return Byte(0);
    }

    Byte read_AUXSPIDATA9(int target_byte) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            return read_AUXSPIDATA(target_byte);
        }

        return Byte(0);
    }

    void write_AUXSPIDATA7(int target_byte, Byte data) {
        if (slot.nds_slot_access_rights == HwType.NDS7) {
            write_AUXSPIDATA(target_byte, data);
        }
    }

    void write_AUXSPIDATA9(int target_byte, Byte data) {
        if (slot.nds_slot_access_rights == HwType.NDS9) {
            write_AUXSPIDATA(target_byte, data);
        }
    }
}