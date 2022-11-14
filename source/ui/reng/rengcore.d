module ui.reng.rengcore;

import re;
import re.math;
import ui.reng;
import std.algorithm.comparison : max;

class RengCore : Core {
    int width;
    int height;
    int screen_scale;
    bool start_full_ui = false;

    this(int screen_scale, bool full_ui) {
        this.start_full_ui = full_ui;

        this.width = 256 * screen_scale;
        this.height = 192 * screen_scale * 2 + SCREEN_SEPARATION_HEIGHT;
        this.screen_scale = screen_scale;

        if (this.start_full_ui) {
            this.width = max(this.width, 1280);
            this.height = max(this.height, 720);

            sync_render_window_resolution = true;
            auto_compensate_hidpi = true;
        }

        super(width, height, "BeanDS");
    }

    override void initialize() {
        default_resolution = Vector2(width, height);
        content.paths ~= ["../content/", "content/"];

        screen_scale *= cast(int) window.scale_dpi;

        if (start_full_ui) {
            load_scenes([new EmuDebugInterfaceScene(screen_scale)]);
        } else {
            load_scenes([new EmuScene(screen_scale)]);
        }
    }

    pragma(inline, true) {
        void update_pub() {
            update();
        }

        void draw_pub() {
            draw();
        }
    }
}
