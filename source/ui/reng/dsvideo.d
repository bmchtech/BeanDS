module ui.reng.dsvideo;

import raylib;
import re;
import re.gfx;
import re.math;
import std.format;
import std.string;

enum SCREEN_SEPARATION_HEIGHT = 0;
enum NDS_SCREEN_WIDTH = 256;
enum NDS_SCREEN_HEIGHT = 192;
enum NDS_VIEW_WIDTH = 256;
enum NDS_VIEW_HEIGHT = NDS_SCREEN_HEIGHT + SCREEN_SEPARATION_HEIGHT + NDS_SCREEN_HEIGHT;

class DSVideo : Component, Updatable, Renderable2D {
    int screen_scale;

    RenderTarget render_target_top;
    RenderTarget render_target_bot;
    RenderTarget render_target_icon;

    uint[NDS_SCREEN_WIDTH * NDS_SCREEN_HEIGHT] videobuffer_top;
    uint[NDS_SCREEN_WIDTH * NDS_SCREEN_HEIGHT] videobuffer_bot;

    this(int screen_scale) {
        this.screen_scale = screen_scale;

        render_target_top = RenderExt.create_render_target(
            NDS_SCREEN_WIDTH,
            NDS_SCREEN_HEIGHT
        );

        render_target_bot = RenderExt.create_render_target(
            NDS_SCREEN_WIDTH,
            NDS_SCREEN_HEIGHT
        );

        render_target_icon = RenderExt.create_render_target(
            32,
            32
        );
    }

    override void setup() {

    }

    void update() {

    }

    void update_icon(uint[32 * 32] icon_bitmap) {
        render_target_icon.texture.format = PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
        UpdateTexture(render_target_icon.texture, cast(const void*) icon_bitmap);
        Image image = LoadImageFromTexture(render_target_icon.texture);
        image.format = PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
        SetWindowIcon(image);
    }
    
    void update_title(string title) {
        SetWindowTitle(toStringz(title));
    }

    void render() {
        UpdateTexture(render_target_top.texture, cast(const void*) videobuffer_top);
        UpdateTexture(render_target_bot.texture, cast(const void*) videobuffer_bot);

        raylib.DrawTexturePro(
            render_target_top.texture,
            Rectangle(0, 0, NDS_SCREEN_WIDTH, NDS_SCREEN_HEIGHT),
            Rectangle(0, 0, NDS_SCREEN_WIDTH * screen_scale, NDS_SCREEN_HEIGHT * screen_scale),
            Vector2(0, 0),
            0,
            Colors.WHITE
        );
        raylib.DrawTexturePro(
            render_target_bot.texture,
            Rectangle(0, 0, NDS_SCREEN_WIDTH, NDS_SCREEN_HEIGHT),
            Rectangle(0, 0, NDS_SCREEN_WIDTH * screen_scale, NDS_SCREEN_HEIGHT * screen_scale),
            Vector2(0, -NDS_SCREEN_HEIGHT * screen_scale - SCREEN_SEPARATION_HEIGHT),
            0,
            Colors.WHITE
        );
    }

    void debug_render() {
        raylib.DrawRectangleLinesEx(bounds, 1, Colors.RED);
    }

    @property Rectangle bounds() {
        return Rectangle(0, 0, NDS_VIEW_WIDTH * screen_scale, NDS_VIEW_HEIGHT * screen_scale);
    }
}