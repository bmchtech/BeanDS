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

    void raise_interrupt(Interrupt code) {
        if (code == Interrupt.GEOMETRY_COMMAND_FIFO) {
            log_gpu3d("received interrupt %s. enabled: %x", code, enable[code]);
        }

        status[code] = 1;
        if (enable & status) cpu.unhalt();
    }

    bool irq_pending() {
        if (this == interrupt9 && master_enable && (enable & status) == (1 << 21)) {
            log_gpu3d("GXFIFO FIRE!");
            // arm9.num_log = 1000;
        }

        return master_enable && (enable & status);
    }

    void write_IF(int target_byte, Byte data) {
        if (this == interrupt9 && target_byte == 2 && data[5]) {
            log_gpu3d("GXFIFO CLEAR! LR: PC: %x %x", arm9.regs[lr], arm9.regs[pc]);                
            for (int i = 0; i < 64; i++) {
                    // arm9.num_log = 100;
                    log_arm9("stack contents: %x", mem9.read!Word(arm9.regs[sp] + i * 4));
                }
            // arm9.num_log = 1000;
        }
        status.set_byte(target_byte, ~data & status.get_byte(target_byte));
    }

    void write_IE(int target_byte, Byte data) {
        Word old_enable = enable;
        enable.set_byte(target_byte, data);

        if (rising_edge(old_enable[21], enable[21])) {
            log_gpu3d("enabled gxfifo irqs");
        } else if (falling_edge(old_enable[21], enable[21])) {
            log_gpu3d("disabled gxfifo irqs");
        }
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