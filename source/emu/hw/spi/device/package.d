module emu.hw.spi.device;

public {
    import emu.hw.spi.device.eeprom;
    import emu.hw.spi.device.firmware;
    import emu.hw.spi.device.touchscreen;
}

import util;

abstract class SPIDevice {
    Half write(Byte b);
    void chipselect_rise();
    void chipselect_fall();
}