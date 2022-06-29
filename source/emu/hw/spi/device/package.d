module emu.hw.spi.device;

public {
    import emu.hw.spi.device.eeprom;
    import emu.hw.spi.device.firmware;
    import emu.hw.spi.device.touchscreen;
}

import util;

abstract class SPIDevice {
    Byte write(Byte b);
    void chipselect_fall();
    void chipselect_rise();
}