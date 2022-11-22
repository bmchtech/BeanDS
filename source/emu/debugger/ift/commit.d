module emu.debugger.ift.commit;

import emu.all;
import util;

struct IFTDebugger {
    static InfoNode[] sources;
    static InfoNode[] effects;
    static Commit[] commits;

    static Snapshot snapshot_start;
    static Snapshot snapshot_end;

    static bool is_debugging;

    static void commit_reg_read(HwType hw_type, Reg reg, CpuMode cpu_mode, Word value) {
        if (!is_debugging) return;

        sources ~= InfoNode(
            InfoType.Register,
            create_logged_reg(hw_type, reg, cpu_mode),
            value
        );
    }

    static void commit_reg_write(HwType hw_type, Reg reg, CpuMode cpu_mode, Word value) {
        if (!is_debugging) return;

        effects ~= InfoNode(
            InfoType.Register,
            create_logged_reg(hw_type, reg, cpu_mode),
            value
        );
    }
    
    static void commit_mem_read(HwType hw_type, Word address, Word value) {
        if (!is_debugging) return;

        sources ~= InfoNode(
            InfoType.Memory,
            create_paddr(hw_type, address),
            value,
        );
    }
    
    static void commit_mem_write(HwType hw_type, Word address, Word value) {
        if (!is_debugging) return;

        effects ~= InfoNode(
            InfoType.Memory,
            create_paddr(hw_type, address),
            value,
        );
    }

    static void instruction_start() {
        sources = [];
        effects = [];
    }

    static void instruction_end() {
        bool only_reg = true;
        bool only_mem = true;

        foreach (effect; effects) {
            switch (effect.type) {
                case InfoType.Register:
                    only_mem = false;
                    break;
                
                case InfoType.Memory:
                    only_reg = false;
                    break;
                
                default: assert(0);
            }
        }

        InfoType effect;
        if      ( only_reg && !only_mem) effect = InfoType.Register;
        else if (!only_reg &&  only_mem) effect = InfoType.Memory;
        else if ( only_reg &&  only_mem) effect = InfoType.Combined;
        else                             effect = InfoType.None;
        
        commits ~= Commit()
            .with_pc(arm7.regs[pc])
            .with_sources(sources)
            .with_effects(effects)
            .with_type(effect);
    }

    static void start_debugging() {
        is_debugging = true;
        snapshot_start = snapshot();
    }

    static void stop_debugging() {
        is_debugging = false;
        snapshot_end = snapshot();

        for (int i = 0; i < commits.length; i++) {
            log_ift("%s", commits[i]);
        }
    }

    static Snapshot snapshot() {
        Snapshot snapshot;

        foreach (hw_type; [HwType.NDS7, HwType.NDS9]) {
        foreach (cpu_mode; [MODE_USER, MODE_SUPERVISOR, MODE_ABORT, MODE_UNDEFINED, MODE_IRQ, MODE_FIQ, MODE_SYSTEM]) {
        foreach (reg; 0..16) {
            ArmCPU arm_cpu = hw_type == HwType.NDS7 ? cast(ArmCPU) arm7 : cast(ArmCPU) arm9;
            auto logged_reg = create_logged_reg(hw_type, reg, cpu_mode);

            snapshot.reg[logged_reg] = arm_cpu.get_reg(reg, cpu_mode);
        }
        }
        }

        // snapshot_mem_region(snapshot, "MAIN_MEMORY", cast(Byte*) main_memory.data, MAIN_MEMORY_SIZE, 0x0200_0000);
        // snapshot_mem_region(snapshot, "PRAM",        cast(Byte*) pram.data,        PRAM.PRAM_SIZE,   0x0500_0000);
        // snapshot_mem_region(snapshot, "OAM",         cast(Byte*) oam.data,         OAM.OAM_SIZE,     0x0700_0000);

        return snapshot;
    }

    private static void snapshot_mem_region(Snapshot snapshot, string name, Byte* memory, int length, int memory_base) {
        import std.algorithm.comparison : min;

        snapshot.memory_map ~= MemoryMap(MemoryMap.Type.Memory, memory_base, name);
        for (auto i = 0; i < length; i += MemoryPageTable.PAGE_SIZE) {
            auto start_address = i;
            snapshot.tracked_mem.make_page(start_address);
            // copy memory block
            auto copy_start = start_address;
            auto copy_end = min(length, start_address + MemoryPageTable.PAGE_SIZE);
            auto copy_size = copy_end - copy_start;

            for (int j = 0; j < copy_size; j++) {
                snapshot.tracked_mem.pages[start_address].mem[j] = cast(ulong) (memory[copy_start + j]);
            }
        }
    }
}