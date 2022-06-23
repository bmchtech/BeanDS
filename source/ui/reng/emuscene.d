module ui.reng.emuscene;

import ui.reng;

import re;

class EmuScene : Scene2D {
    int screen_scale;

    this(int screen_scale) {
        this.screen_scale = screen_scale;
        super();
    }

    override void on_start() {
        auto ds_screen = create_entity("ds_display");
        auto ds_video = ds_screen.add_component(new DSVideo(screen_scale));
        Core.jar.register(ds_video);
    }

    override void update() {
        super.update();
    }
}