module ui.reng.device;

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
        void receive_videobuffer(Pixel[256][192] buffer) {
            ds_video = Core.jar.resolve!DSVideo().get; 

            for (int y = 0; y < 256; y++) {
            for (int x = 0; x < 192;  x++) {
                    ds_video.frame_buffer[y * 256 + x] = 
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

        }
    }
}