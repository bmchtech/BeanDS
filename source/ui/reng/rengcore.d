module ui.reng.rengcore;

import ui.reng;

import re;
import re.math;

class RengCore : Core {
    int width;
    int height;

    this(int screen_scale) {
        this.width  = 256 * screen_scale;
        this.height = 192 * screen_scale * 2;

        super(width, height, "BeanDS");
    }

    override void initialize() {
        default_resolution = Vector2(width, height);
        content.paths ~= ["../content/", "content/"];

        load_scenes([new EmuScene()]);
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