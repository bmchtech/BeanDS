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

    bool vblank_irq_enabled7;
    bool hblank_irq_enabled7;
    bool vcounter_irq_enabled7;
    bool vblank_irq_enabled9;
    bool hblank_irq_enabled9;
    bool vcounter_irq_enabled9;

    bool display_swap;

    int vcount_lyc;

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
        if (hblank_irq_enabled9) interrupt9.raise_interrupt(Interrupt.LCD_HBLANK);
        if (hblank_irq_enabled7) interrupt7.raise_interrupt(Interrupt.LCD_HBLANK);

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

        if (scanline == vcount_lyc) {
            if (vcounter_irq_enabled9) interrupt9.raise_interrupt(Interrupt.LCD_VCOUNT);
            if (vcounter_irq_enabled7) interrupt7.raise_interrupt(Interrupt.LCD_VCOUNT);
        }

        scheduler.add_event_relative_to_self(&on_hblank_start, 256 * 6);
    }

    void set_hblank_flag() {
        hblank = true;
        dma9.on_hblank(scanline);
        dma7.on_hblank(scanline);
    }

    void on_vblank_start() {
        vblank = true;
        gpu_engine_a.ppu.vblank();
        gpu_engine_b.ppu.vblank();
        gpu3d.vblank();

        if (vblank_irq_enabled9) interrupt9.raise_interrupt(Interrupt.LCD_VBLANK);
        if (vblank_irq_enabled7) interrupt7.raise_interrupt(Interrupt.LCD_VBLANK);
    }

    void on_vblank_end() {
        vblank = false;
        scanline = 0;
        
        if (display_swap) {
            present_videobuffers(gpu_engine_a.videobuffer, gpu_engine_b.videobuffer);
        } else {
            present_videobuffers(gpu_engine_b.videobuffer, gpu_engine_a.videobuffer);
        }
    }

    void render() {
        gpu_engine_a.render(scanline);
        gpu_engine_b.render(scanline);
    }

    void set_present_videobuffers_callback(void delegate(Pixel[192][256], Pixel[192][256]) present_videobuffers) {
        this.present_videobuffers = present_videobuffers;
    }

    void write_DISPSTAT7(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                vblank_irq_enabled7   = value[3];
                hblank_irq_enabled7   = value[4];
                vcounter_irq_enabled7 = value[5];
                break;
            case 1:
                vcount_lyc = value;
                break;
        }
    }

    Byte read_DISPSTAT7(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = Byte(vblank);
                result[1] = Byte(hblank);
                result[3] = Byte(vblank_irq_enabled7);
                result[4] = Byte(hblank_irq_enabled7);
                result[5] = Byte(vcounter_irq_enabled7);
                break;

            case 1:
                result = vcount_lyc;
                break;
        }

        return result;
    }

    void write_DISPSTAT9(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                vblank_irq_enabled9   = value[3];
                hblank_irq_enabled9   = value[4];
                vcounter_irq_enabled9 = value[5];
                break;
            case 1:
                vcount_lyc = value;
                break;
        }
    }

    Byte read_DISPSTAT9(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = Byte(vblank);
                result[1] = Byte(hblank);
                result[3] = Byte(vblank_irq_enabled9);
                result[4] = Byte(hblank_irq_enabled9);
                result[5] = Byte(vcounter_irq_enabled9);
                break;

            case 1:
                result = vcount_lyc;
                break;
        }

        return result;
    }

    Byte read_VCOUNT(int target_byte) {
        return Byte((scanline >> (target_byte * 8)) & 0xFF);
    }


    Byte read_POWCNT1(int target_byte) {
        Byte result = 0;

        final switch (target_byte) {
            case 0:
                result[0] = true; // TODO: what to actually return here?
                break;

            case 1:
                result[7] = display_swap;
                break;
        }

        return result;
    }

    void write_POWCNT1(int target_byte, Byte value) {
        final switch (target_byte) {
            case 0:
                break;
            case 1:
                display_swap = value[7];
                break;
        }
    }
}