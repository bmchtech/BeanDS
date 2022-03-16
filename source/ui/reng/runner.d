module ui.reng.runner;

import ui.device;
import ui.reng;

import core.hw;

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

    ulong start_timestamp;

    bool running;

    this(NDS nds, uint cycles_per_batch, MultiMediaDevice frontend) {
        this.nds = nds;
        this.cycles_per_batch = cycles_per_batch;

        this.should_cycle_nds_mutex = new Mutex();

        this.sync_to_audio_lower = frontend.get_samples_per_callback() / 2;
        this.sync_to_audio_upper = frontend.get_samples_per_callback();

        this.frontend = frontend;

        this.fast_forward     = false;
        this.should_cycle_nds = true;
        this.running          = true;
    }

    void tick() {
        frontend.handle_input();

        auto buffer_size = frontend.get_buffer_size();
        if (buffer_size > sync_to_audio_upper) set_should_cycle_nds(false);
        if (buffer_size < sync_to_audio_lower) set_should_cycle_nds(true);
        
		ulong end_timestamp = 0;
		ulong elapsed = end_timestamp - start_timestamp;
        if (elapsed > 1000) {
            frontend.reset_fps();
            start_timestamp = end_timestamp;
        }

        frontend.update();
        frontend.draw();
    }

    void run() {
        start_timestamp = 0;

        while (running) {
            // i separated the ifs so fast fowarding doesn't
            // incur a mutex call from get_should_cycle_nds
            if (true) {
                nds.cycle();
            } else {
                if (get_should_cycle_nds()) {
                    nds.cycle();
                }
            }

            tick();
        }
    }

    bool get_should_cycle_nds() {
        should_cycle_nds_mutex.lock_nothrow();
        bool temp = should_cycle_nds;
        should_cycle_nds_mutex.unlock_nothrow();

        return temp;
    }

    void set_should_cycle_nds(bool value) {
        should_cycle_nds_mutex.lock_nothrow();
        should_cycle_nds = value;
        should_cycle_nds_mutex.unlock_nothrow();
    }

    void stop() {
        running = false;
    }
}