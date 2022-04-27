module emu.hw.spi.auxspi;

import emu;
import util;

__gshared AUXSPI auxspi;

final class AUXSPI {
    private this () {}

    static void reset() {
        auxspi = new AUXSPI();
    }

    bool transfer_completion_irq7_enable;
    bool transfer_completion_irq9_enable;

    void write_AUXSPICNT7(int target_byte, Byte data) {
        if (target_byte == 1) transfer_completion_irq7_enable = data[6];
        if (transfer_completion_irq7_enable) {
            log_auxspi("sussy baka!");
            interrupt7.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION);
        }
    }

    void write_AUXSPICNT9(int target_byte, Byte data) {
        if (target_byte == 1) transfer_completion_irq9_enable = data[6];
        if (transfer_completion_irq9_enable) {
            log_auxspi("sussy baka!");
            interrupt9.raise_interrupt(Interrupt.GAME_CARD_TRANSFER_COMPLETION);
        }
    }

    void write_AUXSPIDATA7(int target_byte, Byte data) {
    }

    void write_AUXSPIDATA9(int target_byte, Byte data) {
    }
}