module ui.reng.device;

import emu.hw;

import ui.device;
import ui.reng;

import re;

class RengMultimediaDevice : MultiMediaDevice {
    RengCore reng_core;
    DSVideo  ds_video;

    this(int screen_scale) {
        Core.target_fps = 999_999;
        reng_core = new RengCore(screen_scale);
    }

    override {
        // video stuffs
        void present_videobuffer(Pixel[192][256] buffer) {
            ds_video = Core.jar.resolve!DSVideo().get; 

            for (int y = 0; y < 192; y++) {
            for (int x = 0; x < 256;  x++) {
                    ds_video.videobuffer[y * 256 + x] = 
                        (buffer[x][y].r << 3 <<  0) |
                        (buffer[x][y].g << 3 <<  8) |
                        (buffer[x][y].b << 3 << 16) |
                        0xFF000000;
            }
            }
        }

        void reset_fps() {

        }

        void push_sample(Sample s) {

        }

        void update() {
            handle_input();
            reng_core.update_pub();
        }

        void draw() {
            reng_core.draw_pub();
        }

        void pause() {

        }

        void play() {

        }

        uint get_sample_rate() {
            return 100;
        }

        uint get_samples_per_callback() {
            return 44100;
        }

        size_t get_buffer_size() {
            return 500;
        }

        void handle_input() {
            static foreach (re_key, gba_key; keys) {
                update_key(gba_key, Input.is_key_down(re_key));
            }

        }
    }

    enum keys = [
        Keys.KEY_Z     : DSKeyCode.A,
        Keys.KEY_X     : DSKeyCode.B,
        Keys.KEY_SPACE : DSKeyCode.SELECT,
        Keys.KEY_ENTER : DSKeyCode.START,
        Keys.KEY_RIGHT : DSKeyCode.RIGHT,
        Keys.KEY_LEFT  : DSKeyCode.LEFT,
        Keys.KEY_UP    : DSKeyCode.UP,
        Keys.KEY_DOWN  : DSKeyCode.DOWN,
        Keys.KEY_S     : DSKeyCode.R,
        Keys.KEY_A     : DSKeyCode.L
    ];
}