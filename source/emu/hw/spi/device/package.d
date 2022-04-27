module emu.hw.spi.device;

public {
    import emu.hw.spi.device.touchscreen;
}

import util;

abstract class SPIDevice {
    Half read();
    void write(Byte b);
}