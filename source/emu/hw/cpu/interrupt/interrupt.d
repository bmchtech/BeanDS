module emu.hw.cpu.interrupt.interrupt;

import emu;
import util;

enum Interrupt {
    LCD_VBLANK                    = 0,
    LCD_HBLANK                    = 1,
    LCD_VCOUNT                    = 2,
    TIMER_0_OVERFLOW              = 3,
    TIMER_1_OVERFLOW              = 4,
    TIMER_2_OVERFLOW              = 5,
    TIMER_3_OVERFLOW              = 6,
    RTC                           = 7, // NDS 7 only
    DMA_0_COMPLETION              = 8,
    DMA_1_COMPLETION              = 9,
    DMA_2_COMPLETION              = 10,
    DMA_3_COMPLETION              = 11,
    KEYPAD                        = 12,
    GBA_SLOT                      = 13,
    IPC_SYNC                      = 16,
    IPC_SEND_FIFO_EMPTY           = 17,
    IPC_RECV_FIFO_NOT_EMPTY       = 18,
    GAME_CARD_TRANSFER_COMPLETION = 19,
    GAME_CARD_IREQ_MC             = 20,
    GEOMETRY_COMMAND_FIFO         = 21, // NDS 9 only
    SCREENS_UNFOLDING             = 22, // NDS 7 only
    SPI_BUS                       = 23, // NDS 7 only
    WIFI                          = 24  // NDS 7 only
}

__gshared InterruptManager interrupt7;
__gshared InterruptManager interrupt9;
final class InterruptManager {
    Word enable;
    Word status;
    bool master_enable;

    ArmCPU cpu;
    
    this(ArmCPU cpu) {
        this.cpu = cpu;
    }

    static void reset() {
        interrupt7 = new InterruptManager(arm7);
        interrupt9 = new InterruptManager(arm9);
    }

    void raise_interrupt(Interrupt code) {
        status[code] = 1;
        if (enable & status) cpu.unhalt();
    }

    bool irq_pending() {
        return master_enable && (enable & status);
    }

    void write_IF(int target_byte, Byte data) {
        status.set_byte(target_byte, ~data & status.get_byte(target_byte));
    }

    void write_IE(int target_byte, Byte data) {
        if (this == interrupt9) log_interrupt("IRQ: %X %X", target_byte, data);
        enable.set_byte(target_byte, data);
    }

    void write_IME(int target_byte, Byte data) {
        if (target_byte == 0) master_enable = data[0];
    }

    Byte read_IF(int target_byte) {
        return status.get_byte(target_byte);
    }

    Byte read_IE(int target_byte) {
        return enable.get_byte(target_byte);
    }

    Byte read_IME(int target_byte) {
        if (target_byte == 0) return Byte(master_enable);
        return Byte(0);
    }
}

void raise_interrupt_for_both_cpus(Interrupt code) {
    interrupt7.raise_interrupt(code);
    interrupt9.raise_interrupt(code);
}