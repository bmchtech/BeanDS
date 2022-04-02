module ui.device;

import emu.hw;

alias SetKey = void delegate(DSKeyCode key, bool value);

struct Sample {
    short L;
    short R;
}

abstract class MultiMediaDevice {
    SetKey update_key;

    final void set_update_key_callback(SetKey update_key) {
        this.update_key = update_key;
    }

    abstract {
        void update();
        void draw();

        // video stuffs
        void present_videobuffers(Pixel[192][256], Pixel[192][256] buffer);
        void reset_fps();

        // audio stuffs
        void push_sample(Sample s);
        void pause();
        void play();
        uint get_sample_rate();
        uint get_samples_per_callback();
        size_t get_buffer_size();

        // input stuffs
        void handle_input();
    }
}