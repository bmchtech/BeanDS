module ui.reng.rengcore;

import re;
import re.math;
import ui.reng;

class RengCore : Core {
    int width;
    int height;
    int screen_scale;

    this(int screen_scale) {
        this.width  = 256 * screen_scale;
        this.height = 192 * screen_scale * 2 + SCREEN_SEPARATION_HEIGHT;
        this.screen_scale = screen_scale;

        super(width, height, "BeanDS");
    }

    override void initialize() {
        default_resolution = Vector2(width, height);
        content.paths ~= ["../content/", "content/"];

        load_scenes([new EmuScene(screen_scale)]);
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