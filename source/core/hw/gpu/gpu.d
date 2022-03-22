module core.hw.gpu.gpu;

import core.hw;
import core.scheduler;

import util;

__gshared GPU gpu;

final class GPU {
    int  dot;
    int  scanline;
    bool enabled;
    bool vblank;
    bool hblank;

    void delegate(Pixel[192][256]) present_videobuffer;

    this() {
        dot      = 0;
        scanline = 0;

        scheduler.add_event_relative_to_clock(&on_hblank_start, 256 * 6);

        enabled = true;

        new PRAM();
        new VRAM();
        
        gpu = this;
    }

    // void set_frontend_vblank_callback(void delegate(Pixel[SCREEN_HEIGHT][SCREEN_WIDTH]) frontend_vblank_callback) {
    //     this.frontend_vblank_callback = frontend_vblank_callback;
    // }

    void on_hblank_start() {
        // if (hblank_irq_enabled) interrupt_cpu(Interrupt.LCD_HBLANK);

        if (scanline >= 0 && scanline < 192) {
            render();
        }

        scheduler.add_event_relative_to_self(&on_hblank_end, 99 * 6);
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

        scheduler.add_event_relative_to_self(&on_hblank_start, 256 * 6);
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
        present_videobuffer(gpu_engine_a.videobuffer);
    }

    void render() {
        gpu_engine_a.render(scanline);
    }

    void set_present_videobuffer_callback(void delegate(Pixel[192][256]) present_videobuffer) {
        this.present_videobuffer = present_videobuffer;
    }

    void write_DISPSTAT(int target_byte, Byte value) {

    }

    Byte read_DISPSTAT(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = Byte(vblank);
                result[1] = Byte(hblank);
                break;

            case 1: break;

            case 2: break;

            case 3: break; 
        }

        return result;
    }
}