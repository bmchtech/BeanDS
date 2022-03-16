module core.hw.gpu.engines.engine_a;

import core.hw;
import core.scheduler;

import util;

__gshared GPUEngineA gpu_engine_a;
final class GPUEngineA {
    int  dot;
    int  scanline;
    bool enabled;
    bool vblank;
    bool hblank;

    this() {
        dot      = 0;
        scanline = 0;

        scheduler.add_event_relative_to_clock(&on_hblank_start, 256 * 4);

        // frame_buffer = new Pixel[SCREEN_HEIGHT][SCREEN_WIDTH];
        enabled = true;

        gpu_engine_a = this;
    }

    // void set_frontend_vblank_callback(void delegate(Pixel[SCREEN_HEIGHT][SCREEN_WIDTH]) frontend_vblank_callback) {
    //     this.frontend_vblank_callback = frontend_vblank_callback;
    // }

    void on_hblank_start() {
        // if (hblank_irq_enabled) interrupt_cpu(Interrupt.LCD_HBLANK);

        if (scanline >= 0 && scanline < 192) {
            render();
        }

        scheduler.add_event_relative_to_self(&on_hblank_end, 68 * 4);
        scheduler.add_event_relative_to_self(&set_hblank_flag, 46);
    }

    void on_hblank_end() {
        hblank = false;

        scanline++;
        if (scanline == 192) on_vblank_start();
        if (scanline == 263) on_vblank_end();

        // if (vcounter_irq_enabled && scanline == vcount_lyc) {
        //     interrupt_cpu(Interrupt.LCD_VCOUNTER_MATCH);
        // }

        scheduler.add_event_relative_to_self(&on_hblank_start, 240 * 4);
    }

    void set_hblank_flag() {
        hblank = true;
    }

    void on_vblank_start() {
        vblank = true;

        // if (vblank_irq_enabled) interrupt_cpu(Interrupt.LCD_VBLANK);
    }

    void on_vblank_end() {
        vblank = false;
        scanline = 0;
        // frontend_vblank_callback(frame_buffer);
    }

    void render() {

    }

    int bg_mode;
    void write_DISPCNT(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                bg_mode = value[0..2];
                break;

            case 1: break;

            case 2: break;

            case 3: break; 
        }    
    }

    Byte read_DISPCNT(int target_byte) {
        return Byte(0);
    }
}