module emu.hw.gpu.gpu;

import emu.hw;
import emu.scheduler;
import std.algorithm;
import util;

__gshared GPU gpu;

final class GPU {
    Mem mem;
    
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

    void delegate(Pixel[192][256]*, Pixel[192][256]*) present_videobuffers;

    this(Mem mem) {
        dot      = 0;
        scanline = 0;

        scheduler.add_event_relative_to_clock(&on_hblank_start, 256 * 6);

        enabled = true;

        vram = new VRAM(mem);
    }

    // void set_frontend_vblank_callback(void delegate(Pixel[192][256]) frontend_vblank_callback) {
    //     this.frontend_vblank_callback = frontend_vblank_callback;
    // }

    void on_hblank_start() {
        if (hblank_irq_enabled9) interrupt9.raise_interrupt(Interrupt.LCD_HBLANK);
        if (hblank_irq_enabled7) interrupt7.raise_interrupt(Interrupt.LCD_HBLANK);

        gpu_engine_a.hblank(scanline);
        gpu_engine_b.hblank(scanline);

        gpu_engine_a.ppu.canvas.on_hblank_start();
        gpu_engine_b.ppu.canvas.on_hblank_start();

        if (scanline >= 0 && scanline < 192) {
            render();
        }

        scheduler.add_event_relative_to_self(&on_hblank_end, 99 * 6);
        scheduler.add_event_relative_to_self(&set_hblank_flag, 46);
    }

    void on_hblank_end() {
        hblank = false;

        scanline++;

        gpu_engine_a.ppu.canvas.on_hblank_end(scanline);
        gpu_engine_b.ppu.canvas.on_hblank_end(scanline);
        
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

        if (0 <= scanline && scanline < 192) {
            dma9.on_hblank(scanline);
            dma7.on_hblank(scanline);
        }
    }

    void on_vblank_start() {
        vblank = true;
        gpu_engine_a.vblank();
        gpu_engine_b.vblank();

        if (vblank_irq_enabled9) interrupt9.raise_interrupt(Interrupt.LCD_VBLANK);
        if (vblank_irq_enabled7) interrupt7.raise_interrupt(Interrupt.LCD_VBLANK);
    }

    void on_vblank_end() {
        vblank = false;
        scanline = 0;

        apply_master_brightness_to_video_buffers(&gpu_engine_a.videobuffer, &gpu_engine_b.videobuffer);
        
        if (display_swap) {
            present_videobuffers(&gpu_engine_a.videobuffer, &gpu_engine_b.videobuffer);
        } else {
            present_videobuffers(&gpu_engine_b.videobuffer, &gpu_engine_a.videobuffer);
        }
    }

    void render() {
        gpu_engine_a.render(scanline);
        gpu_engine_b.render(scanline);
    }

    void set_present_videobuffers_callback(void delegate(Pixel[192][256]*, Pixel[192][256]*) present_videobuffers) {
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

    enum MasterBrightMode {
        DISABLED = 0,
        UP       = 1,
        DOWN     = 2,
        RESERVED = 3
    }

    MasterBrightMode master_bright_mode_a = MasterBrightMode.DISABLED;
    int master_bright_factor_a;
    int master_brightness_a;

    MasterBrightMode master_bright_mode_b = MasterBrightMode.DISABLED;
    int master_bright_factor_b;
    int master_brightness_b;

    void apply_master_brightness_to_video_buffers(Pixel[192][256]* top, Pixel[192][256]* bot) {
        apply_master_brightness_to_video_buffer(top, master_brightness_a, master_bright_mode_a);
        apply_master_brightness_to_video_buffer(bot, master_brightness_b, master_bright_mode_b);
    }

    void apply_master_brightness_to_video_buffer(Pixel[192][256]* video_buffer, ref int master_brightness, ref MasterBrightMode master_bright_mode) {        import std.stdio;
        final switch (master_bright_mode) {
            case MasterBrightMode.UP:
                for (int x = 0; x < 256; x++) {
                for (int y = 0; y < 192; y++) {
                    auto pixel = (*video_buffer)[x][y];

                    pixel.r = (pixel.r + (63 - pixel.r) * master_brightness / 16);
                    pixel.g = (pixel.g + (63 - pixel.g) * master_brightness / 16);
                    pixel.b = (pixel.b + (63 - pixel.b) * master_brightness / 16);

                    pixel.r = clamp(pixel.r, 0, 63);
                    pixel.g = clamp(pixel.g, 0, 63);
                    pixel.b = clamp(pixel.b, 0, 63);
                }
                }
                break;

            case MasterBrightMode.DOWN:
                for (int x = 0; x < 256; x++) {
                for (int y = 0; y < 192; y++) {
                    auto pixel = (*video_buffer)[x][y];

                    pixel.r = (pixel.r - pixel.r * master_brightness / 16);
                    pixel.g = (pixel.g - pixel.g * master_brightness / 16);
                    pixel.b = (pixel.b - pixel.b * master_brightness / 16);

                    pixel.r = clamp(pixel.r, 0, 63);
                    pixel.g = clamp(pixel.g, 0, 63);
                    pixel.b = clamp(pixel.b, 0, 63);
                }
                }
                break;

            case MasterBrightMode.DISABLED:
                break;
            
            case MasterBrightMode.RESERVED:
                break;
        }
    }

    void write_MASTER_BRIGHT_A(int target_byte, Byte value) {
        modify_master_bright(target_byte, value, master_brightness_a, master_bright_factor_a, master_bright_mode_a);
    }

    void write_MASTER_BRIGHT_B(int target_byte, Byte value) {
        modify_master_bright(target_byte, value, master_brightness_b, master_bright_factor_b, master_bright_mode_b);
    }

    void modify_master_bright(int target_byte, Byte value, ref int master_brightness, ref int master_bright_factor, ref MasterBrightMode master_bright_mode) {
        final switch (target_byte) {
            case 0:
                master_bright_factor = clamp(cast(int) value, 0, 16);

                switch (master_bright_mode) {
                    case MasterBrightMode.UP:
                        master_brightness = clamp(master_brightness, 0, 63);
                        break;

                    case MasterBrightMode.DOWN:
                        master_brightness = clamp(master_brightness, 0, 63);
                        break;
                    
                    default: break;
                }
                break;
            
            case 1:
                master_bright_mode = cast(MasterBrightMode) value[6..7];
        }
    }

    Byte read_MASTER_BRIGHT_A(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result = Byte(master_bright_factor_a);
                break;
            
            case 1:
                result[6..7] = Byte(master_bright_mode_a);
                break;
        }

        return result;
    }

    Byte read_MASTER_BRIGHT_B(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result = Byte(master_bright_factor_b);
                break;
            
            case 1:
                result[6..7] = Byte(master_bright_mode_b);
                break;
        }

        return result;
    }
}