module emu.hw.gpu.gpu;

import emu.hw;
import emu.scheduler;

import util;

__gshared GPU gpu;

final class GPU {
    int  dot;
    int  scanline;
    bool enabled;
    bool vblank;
    bool hblank;

    bool vblank_irq_enabled;
    bool hblank_irq_enabled;
    bool vcounter_irq_enabled;

    void delegate(Pixel[192][256], Pixel[192][256]) present_videobuffers;

    this() {
        dot      = 0;
        scanline = 0;

        scheduler.add_event_relative_to_clock(&on_hblank_start, 256 * 6);

        enabled = true;

        new PRAM();
        new VRAM();
        OAM.reset();
        
        gpu = this;
    }

    // void set_frontend_vblank_callback(void delegate(Pixel[192][256]) frontend_vblank_callback) {
    //     this.frontend_vblank_callback = frontend_vblank_callback;
    // }

    void on_hblank_start() {
        if (hblank_irq_enabled) raise_interrupt_for_both_cpus(Interrupt.LCD_HBLANK);

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
        //     raise_interrupt_for_both_cpus(Interrupt.LCD_VCOUNTER_MATCH);
        // }

        scheduler.add_event_relative_to_self(&on_hblank_start, 256 * 6);
    }

    void set_hblank_flag() {
        hblank = true;
    }

    void on_vblank_start() {
        vblank = true;
        // gpu_engine_a.ppu.vblank();
        gpu_engine_b.ppu.vblank();

        if (vblank_irq_enabled) raise_interrupt_for_both_cpus(Interrupt.LCD_VBLANK);
    }

    void on_vblank_end() {
        vblank = false;
        scanline = 0;

        present_videobuffers(gpu_engine_a.videobuffer, gpu_engine_b.videobuffer);
    }

    void render() {
        gpu_engine_a.render(scanline);
        gpu_engine_b.render(scanline);
    }

    void set_present_videobuffers_callback(void delegate(Pixel[192][256], Pixel[192][256]) present_videobuffers) {
        this.present_videobuffers = present_videobuffers;
    }

    void write_DISPSTAT(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                vblank_irq_enabled   = value[3];
                hblank_irq_enabled   = value[4];
                vcounter_irq_enabled = value[5];
                break;
            case 1:
            case 2:
            case 3:
                break;
        }
    }

    Byte read_DISPSTAT(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = Byte(vblank);
                result[1] = Byte(hblank);
                result[3] = Byte(vblank_irq_enabled);
                result[4] = Byte(hblank_irq_enabled);
                result[5] = Byte(vcounter_irq_enabled);
                break;

            case 1: break;

            case 2: break;

            case 3: break; 
        }

        return result;
    }
}