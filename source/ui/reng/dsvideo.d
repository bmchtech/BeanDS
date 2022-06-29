module ui.reng.dsvideo;

import re;
import re.math;
import re.gfx;

import std.format;
import std.string;

import raylib;

enum SCREEN_SEPARATION_HEIGHT = 0;

class DSVideo : Component, Updatable, Renderable2D {
    int screen_scale;

    RenderTarget render_target_top;
    RenderTarget render_target_bot;
    RenderTarget render_target_icon;

    uint[256 * 192] videobuffer_top;
    uint[256 * 192] videobuffer_bot;

    this(int screen_scale) {
        this.screen_scale = screen_scale;

        render_target_top = RenderExt.create_render_target(
            256,
            192
        );

        render_target_bot = RenderExt.create_render_target(
            256,
            192
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
            Rectangle(0, 0, 256, 192),
            Rectangle(0, 0, 256 * screen_scale, 192 * screen_scale),
            Vector2(0, 0),
            0,
            Colors.WHITE
        );
        raylib.DrawTexturePro(
            render_target_bot.texture,
            Rectangle(0, 0, 256, 192),
            Rectangle(0, 0, 256 * screen_scale, 192 * screen_scale),
            Vector2(0, -192 * screen_scale - SCREEN_SEPARATION_HEIGHT),
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