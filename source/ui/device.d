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
        bool should_cycle_nds();

        // video stuffs
        void present_videobuffers(Pixel[192][256], Pixel[192][256] buffer);
        void set_fps(int fps);

        // audio stuffs
        void push_sample(Sample s);

        // input stuffs
        void handle_input();
    }
}