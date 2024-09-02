module ui.reng.device;

import emu.hw;
import raylib;
import re;
import std.format;
import std.string;
import ui.device;
import ui.reng;
import util.log;

class RengMultimediaDevice : MultiMediaDevice {
    enum SAMPLE_RATE            = 48_000;
    enum SAMPLES_PER_UPDATE     = 4096;
    enum BUFFER_SIZE_MULTIPLIER = 3;
    enum NUM_CHANNELS           = 2;

    enum FAST_FOWARD_KEY        = Keys.KEY_TAB;

    RengCore reng_core;
    DSVideo  ds_video;
    AudioStream stream;

    bool fast_forward;

    string rom_title;
    int fps;
    int screen_scale;

    this(int screen_scale, bool full_ui) {
        Core.target_fps = 60;
        reng_core = new RengCore(screen_scale, full_ui);
        this.screen_scale = screen_scale;

        InitAudioDevice();
        SetAudioStreamBufferSizeDefault(SAMPLES_PER_UPDATE);
        stream = LoadAudioStream(SAMPLE_RATE, 16, NUM_CHANNELS);
        PlayAudioStream(stream);
        
        ds_video = Core.jar.resolve!DSVideo().get; 
    }

    override {
        // video stuffs
        void present_videobuffers(Pixel[192][256]* buffer_top, Pixel[192][256]* buffer_bot) {
            for (int y = 0; y < 192; y++) {
            for (int x = 0; x < 256;  x++) {
                    ds_video.videobuffer_top[y * 256 + x] = 
                        ((*buffer_top)[x][y].r << 2 <<  0) |
                        ((*buffer_top)[x][y].g << 2 <<  8) |
                        ((*buffer_top)[x][y].b << 2 << 16) |
                        0xFF000000;
                    ds_video.videobuffer_bot[y * 256 + x] = 
                        ((*buffer_bot)[x][y].r << 2 <<  0) |
                        ((*buffer_bot)[x][y].g << 2 <<  8) |
                        ((*buffer_bot)[x][y].b << 2 << 16) |
                        0xFF000000;
            }
            }
        }

        void set_fps(int fps) {
            this.fps = fps;
            redraw_title();
        }

        void update_rom_title(string rom_title) {
            import std.string;
            this.rom_title = rom_title.splitLines[0].strip;
            redraw_title();
        }

        void update_icon(Pixel[32][32] buffer_texture) {
            import std.stdio;

            uint[32 * 32] icon_texture;

            for (int x = 0; x < 32; x++) {
            for (int y = 0; y < 32; y++) {
                icon_texture[y * 32 + x] = 
                    (buffer_texture[x][y].r << 2 <<  0) |
                    (buffer_texture[x][y].g << 2 <<  8) |
                    (buffer_texture[x][y].b << 2 << 16) |
                    (buffer_texture[x][y].a << 3 << 24);
            }
            }

            ds_video.update_icon(icon_texture);
        }

        // 2 cuz stereo
        short[NUM_CHANNELS * SAMPLES_PER_UPDATE * BUFFER_SIZE_MULTIPLIER] buffer;
        int buffer_cursor = 0;

        void push_sample(Sample s) {
            if (buffer_cursor >= NUM_CHANNELS * SAMPLES_PER_UPDATE * BUFFER_SIZE_MULTIPLIER) return;

            auto sample_l = s.L;
            auto sample_r = s.R;

            // NDS samples are unsigned, with a midpoint at 0x200.
            // The frontend uses signed samples, with a midpoint at 0.
            // We need to convert the NDS samples to signed samples:
            sample_l -= 0x200;
            sample_r -= 0x200;

            sample_l <<= 5;
            sample_r <<= 5;

            buffer[buffer_cursor + 0] = sample_l;
            buffer[buffer_cursor + 1] = sample_r;
            buffer_cursor += 2;
        }

        void update() {
            Core.target_fps = buffer_cursor < NUM_CHANNELS * SAMPLES_PER_UPDATE * (BUFFER_SIZE_MULTIPLIER - 1) ? 999 : 60;

            handle_input();
            handle_audio();
            reng_core.update_pub();
        }

        void draw() {
            reng_core.draw_pub();
        }

        bool should_cycle_nds() {
            return true;
            // return buffer_cursor < NUM_CHANNELS * (BUFFER_SIZE_MULTIPLIER - 1) * SAMPLES_PER_UPDATE;
        }

        void handle_input() {
            import std.algorithm.comparison;

            update_key(DSKeyCode.PEN_DOWN, Input.is_mouse_down(MOUSE_LEFT_BUTTON));

            auto mouse_position = Input.mouse_position();

            update_touchscreen_position(
                clamp(cast(int) mouse_position.x / screen_scale,       0, 256),
                clamp(cast(int) mouse_position.y / screen_scale - 192, 0, 192)
            );
            
            static foreach (re_key, gba_key; keys) {
                update_key(gba_key, Input.is_key_down(re_key));
            }

            fast_forward = Input.is_key_down(FAST_FOWARD_KEY);
        }

        bool should_fast_forward() {
            return fast_forward;
        }
    }

    void redraw_title() {
        import std.format;
        ds_video.update_title("%s [FPS: %d]".format(rom_title, fps));
    }

    short[200] sine_buffer;
    import std.math;
    int sine_cursor = 0;
    void sine_wave() {
        int period = 100;
        for (int i = 0; i < 100; i++) {
            sine_buffer[i * 2 + 0] = cast(short) (sin(2 * PI * i / period) * 1000);
            sine_buffer[i * 2 + 1] = cast(short) (sin(2 * PI * i / period) * 1000);
        }
    }

    void handle_audio() {
        if (IsAudioStreamProcessed(stream)) {
            // sine_wave();
            // for (int i = 0; i < SAMPLES_PER_UPDATE * NUM_CHANNELS; i++) {
            //     buffer[i] = sine_buffer[sine_cursor % (100 * NUM_CHANNELS)];
            //     sine_cursor++;
            //     sine_cursor %= 100 * NUM_CHANNELS;
            // }

            // Fill with zeros
            for (int i = buffer_cursor; i < NUM_CHANNELS * SAMPLES_PER_UPDATE * (BUFFER_SIZE_MULTIPLIER - 1); i++) {
                buffer[i] = 0;
            }

            UpdateAudioStream(stream, cast(void*) buffer, SAMPLES_PER_UPDATE);
            
            for (int i = 0; i < NUM_CHANNELS * SAMPLES_PER_UPDATE * (BUFFER_SIZE_MULTIPLIER - 1); i++) {
                buffer[i] = buffer[i + NUM_CHANNELS * SAMPLES_PER_UPDATE];
            }

            buffer_cursor -= NUM_CHANNELS * SAMPLES_PER_UPDATE;
            if (buffer_cursor < 0) {
                buffer_cursor = 0;
                log_nds("Audio buffer underflowed");
            }

            if (fast_forward) buffer_cursor = 0;
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
        Keys.KEY_A     : DSKeyCode.X,
        Keys.KEY_S     : DSKeyCode.Y,
        Keys.KEY_E     : DSKeyCode.R,
        Keys.KEY_Q     : DSKeyCode.L
    ];
}