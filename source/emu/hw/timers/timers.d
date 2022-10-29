module emu.hw.timers.timers;

import emu.hw.cpu.interrupt;
import emu.scheduler;

import util;

__gshared TimerManager timers7;
__gshared TimerManager timers9;
final class TimerManager {
    InterruptManager interrupt_manager;

    this(InterruptManager interrupt_manager) {
        timers = [
            Timer(),
            Timer(),
            Timer(),
            Timer()
        ];
    
        this.interrupt_manager = interrupt_manager;
    }

    void reload_timer(int timer_id) {
        // check for cancellation
        if (timers[timer_id].countup && timer_id != 0) {
            timers[timer_id].value = timers[timer_id].reload_value;
            return;
        }

        if (!timers[timer_id].enabled) return;

        timers[timer_id].enabled_for_first_time = false;
        timers[timer_id].value = timers[timer_id].reload_value;
        ulong timestamp = scheduler.get_current_time_relative_to_self();
        timers[timer_id].timer_event = scheduler.add_event_relative_to_self(() => timer_overflow(timer_id), (0x10000 - timers[timer_id].reload_value) << timers[timer_id].increment);

        timers[timer_id].timestamp = scheduler.get_current_time_relative_to_self();
    }


    void reload_timer_for_the_first_time(int timer_id) {
        if (timer_id != 0 && timers[timer_id].countup) return;

        timers[timer_id].enabled_for_first_time = true;
        timers[timer_id].value = timers[timer_id].reload_value;
        timers[timer_id].reload_value_buffer = timers[timer_id].reload_value;
        timers[timer_id].timer_event = scheduler.add_event_relative_to_clock(() => timer_overflow(timer_id), 2 + ((0x10000 - timers[timer_id].reload_value) << timers[timer_id].increment));
        timers[timer_id].timestamp = scheduler.get_current_time_relative_to_cpu() + 2;
    }

    void timer_overflow(int x) {
        timers[x].reload_value_buffer = timers[x].reload_value;
        reload_timer(x);
        // TODO: the commented out code is from the GBA. what should i do here instead?
        // on_timer_overflow(x);

        if (timers[x].irq_enable) {
            interrupt_manager.raise_interrupt(get_interrupt_from_timer_id(x));
        }

        // if the next timer is a slave (countup), then increment it
        if (x < 3 && timers[x + 1].countup) {
            if (timers[x + 1].value == 0xFFFF) timer_overflow(x + 1);
            else timers[x + 1].value++;
        }
    }

    Interrupt get_interrupt_from_timer_id(int x) {
        final switch (x) {
            case 0: return Interrupt.TIMER_0_OVERFLOW;
            case 1: return Interrupt.TIMER_1_OVERFLOW;
            case 2: return Interrupt.TIMER_2_OVERFLOW;
            case 3: return Interrupt.TIMER_3_OVERFLOW;
        }
    }

    ushort calculate_timer_value(int x) {
        // am i enabled? if not just return without calculation
        // also, if i'm countup, then im a slave timer. timers[x - 1] will
        // control my value instead
        
        if (x != 0 && timers[x].countup) {
            // let's get the id of the master timer
            int master_timer = x;
            while (timers[master_timer].countup && master_timer != 0) master_timer--;
            return timers[x].value;
        }
        
        // how many clock cycles has it been since we've been enabled?
        ulong cycles_elapsed = scheduler.get_current_time_relative_to_cpu() - timers[x].timestamp;

        // use timer increments to get the relevant bits, and mod by the reload value
        return cast(ushort) ((cycles_elapsed >> timers[x].increment) + timers[x].reload_value_buffer);
    }

    Timer[4] timers;

    uint[4] increment_shifts = [0, 6, 8, 10];

    struct Timer {
        Half  reload_value;
        ushort  reload_value_buffer;
        ushort  value;
        int     increment;
        int     increment_index;
        bool    enabled;
        bool    countup;
        bool    irq_enable;
        bool    enabled_for_first_time;

        ulong   timestamp;

        ulong   timer_event;
    }

    void write_TMxCNT_L(int target_byte, Byte data, int x) {
        timers[x].reload_value.set_byte(target_byte, data);
    }

    void write_TMxCNT_H(int target_byte, Byte data, int x) {
        final switch (target_byte) {
            case 0: 
                timers[x].increment_index = data[0..1];
                timers[x].countup         = data[2];
                timers[x].irq_enable      = data[6];

                timers[x].increment = increment_shifts[data[0..1]];

                // are we enabling the timer?
                if (!timers[x].enabled && data[7]) {
                    timers[x].enabled = true;

                    if (timers[x].timer_event != 0) scheduler.remove_event(timers[x].timer_event);

                    timers[x].value = timers[x].reload_value;
                    reload_timer_for_the_first_time(x);
                }

                if (!data[7]) {
                    timers[x].enabled = false;
                    timers[x].value = calculate_timer_value(x);
                    scheduler.remove_event(timers[x].timer_event);
                }

                break;
            case 1: 
                break;
        }
    }

    Byte read_TMxCNT_L(int target_byte, int x) {
        if (timers[x].enabled) 
            timers[x].value = calculate_timer_value(x);

        return Half(timers[x].value).get_byte(target_byte);
    }

    Byte read_TMxCNT_H(int target_byte, int x) {
        final switch (target_byte) {
            case 0: 
                return cast(Byte) ((timers[x].increment_index  << 0) | 
                                    (timers[x].countup          << 2) |
                                    (timers[x].irq_enable       << 6) |
                                    (timers[x].enabled          << 7));
            case 1: 
                return Byte(0);
        }
    }
}