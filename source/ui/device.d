module ui.device;

import core.hw;

alias SetKey = void delegate(int key, bool value);

struct Sample {
    short L;
    short R;
}

abstract class MultiMediaDevice {
    SetKey set_vanilla_key;

    final void set_callbacks(SetKey set_vanilla_key) {
        this.set_vanilla_key = set_vanilla_key;
    }

    abstract {
        void update();
        void draw();

        // video stuffs
        void present_videobuffer(Pixel[192][256] buffer);
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