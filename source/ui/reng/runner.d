module ui.reng.runner;

import ui.device;
import ui.reng;

import emu.hw;

import std.datetime.stopwatch;

import core.sync.mutex;

final class Runner {
    NDS nds;
    bool fast_forward;

    Mutex should_cycle_nds_mutex;
    bool should_cycle_nds;
    uint cycles_per_batch;

    MultiMediaDevice frontend;

    size_t sync_to_audio_lower;
    size_t sync_to_audio_upper;

    StopWatch stopwatch;

    bool running;

    int fps = 0;

    this(NDS nds, uint cycles_per_batch, MultiMediaDevice frontend) {
        this.nds = nds;
        this.cycles_per_batch = cycles_per_batch;

        this.should_cycle_nds_mutex = new Mutex();

        this.frontend = frontend;

        this.should_cycle_nds = true;
        this.running          = true;
    }

    void tick() {
        if (stopwatch.peek.total!"msecs" > 1000) {
            frontend.set_fps(fps);
            stopwatch.reset();
            fps = 0;
        }

        frontend.update();
        frontend.draw();
    }

    void run() {
        stopwatch = StopWatch(AutoStart.yes);

        while (running) {
            if (frontend.should_cycle_nds() || frontend.should_fast_forward()) {
                nds.cycle(33_513_982 / 60);
                fps++;
            }
            
            tick();
        }
    }
}