module ui.reng.dsvideo;

import re;
import re.math;
import re.gfx;

import raylib;

class DSVideo : Component, Updatable, Renderable2D {
    int screen_scale;

    RenderTarget render_target;
    Texture2D rp1_texture;

    uint[256 * 192] videobuffer;

    this(int screen_scale) {
        this.screen_scale = screen_scale;
        render_target = RenderExt.create_render_target(
            256,
            192
        );
    }

    override void setup() {

    }

    void update() {

    }

    void render() {
        UpdateTexture(render_target.texture, cast(const void*) videobuffer);

        raylib.DrawTexturePro(
            render_target.texture,
            Rectangle(0, 0, 256, 192),
            Rectangle(0, 0, 256 * screen_scale, 192 * screen_scale),
            Vector2(0, 0),
            0,
            Colors.WHITE
        );
    }

    void debug_render() {
        // leave this blank
    }

    @property Rectangle bounds() {
        // if we're not using culling who cares
        // problem solved lol
        return Rectangle(0, 0, 1000, 1080);
    }
}