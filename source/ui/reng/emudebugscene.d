module ui.reng.emudebugscene;

import re;
import ui.reng;

class EmuDebugInterfaceScene : Scene2D {
    int screen_scale;

    this(int screen_scale) {
        this.screen_scale = screen_scale;
        super();
    }

    override void on_start() {
        auto ds_screen = create_entity("ds_display");
        auto ds_video = ds_screen.add_component(new DSVideo(screen_scale));
        Core.jar.register(ds_video);

        // add debugger ui
        auto ds_debugger_nt = create_entity("ds_debugger");
        ds_debugger_nt.add_component(new DSDebuggerUIRoot());
    }

    override void update() {
        super.update();
    }
}