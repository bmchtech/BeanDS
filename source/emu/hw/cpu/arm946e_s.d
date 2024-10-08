module emu.hw.cpu.arm946e_s;

import emu.debugger.cputrace;
import emu.hw.cpu.architecture;
import emu.hw.cpu.armcpu;
import emu.hw.cpu.cp.cp15;
import emu.hw.cpu.cp.tcm;
import emu.hw.cpu.instructionblock;
import emu.hw.cpu.interrupt;
import emu.hw.cpu.jumptable.jumptable_arm;
import emu.hw.cpu.jumptable.jumptable_thumb;
import emu.hw.memory.cart.cart;
import emu.hw.memory.mem;
import emu.hw.memory.mem9;
import emu.hw.memory.strategy.memstrategy;
import emu.hw.spi.device.firmware;
import emu.scheduler;
import util;

__gshared ARM946E_S arm9;
final class ARM946E_S : ArmCPU {
    Word[18 * 7] register_file;
    Word[18]     regs;

    Word[2] arm_pipeline;
    Half[2] thumb_pipeline;

    InstructionSet instruction_set;   

    bool enabled = false;
    bool halted  = false; 

    CpuMode current_mode;

    CpuTrace cpu_trace;

    ulong num_log;

    InstructionBlock* instruction_block;
    Word current_instruction_block_address = 0x06000000;

    Mem mem;

    this(Mem mem, uint ringbuffer_size) {
        current_mode = MODE_USER;
        arm9 = this;
        this.mem = mem;

        cpu_trace = new CpuTrace(this, ringbuffer_size);
        cp15 = new Cp15();
        tcm = new TCM();
    }

    void reset() {
        set_mode!MODE_SYSTEM;
        current_mode = MODE_SYSTEM;
        for (int i = 0; i < 7; i++) {
            register_file[MODES[i].OFFSET + 16] |= MODES[i].CPSR_ENCODING;
        }    

        regs[0 .. 18] = register_file[MODE_USER.OFFSET .. MODE_USER.OFFSET + 18];
    
        set_reg(pc, Word(get_address_from_exception!(CpuException.Reset)));
    }

    void direct_boot() {
        register_file[MODE_USER      .OFFSET + sp] = 0x0300_2F7C;
        register_file[MODE_IRQ       .OFFSET + sp] = 0x0300_3F7C;
        register_file[MODE_SUPERVISOR.OFFSET + sp] = 0x0300_3FC0;

        internal_write!Word(Word(0x27FF800), cart.get_cart_id());
        internal_write!Word(Word(0x27FF804), cart.get_cart_id());
        internal_write!Word(Word(0x27FFC00), cart.get_cart_id());
        internal_write!Word(Word(0x27FFC04), cart.get_cart_id());
        internal_write!Word(Word(0x27FFC3C), Word(0x00000332));
        internal_write!Word(Word(0x27FFC40), Word(1)); // boot flag

        // obtained from the no$gba emulator
        internal_write!Half(Word(0x27FFCD8), firmware.user_settings.adc_x1);
        internal_write!Half(Word(0x27FFCDA), firmware.user_settings.adc_y1);
        internal_write!Byte(Word(0x27FFCDC), firmware.user_settings.scr_x1);
        internal_write!Byte(Word(0x27FFCDD), firmware.user_settings.scr_y1);
        internal_write!Half(Word(0x27FFCDE), firmware.user_settings.adc_x2);
        internal_write!Half(Word(0x27FFCE0), firmware.user_settings.adc_y2);
        internal_write!Byte(Word(0x27FFCE2), firmware.user_settings.scr_x2);
        internal_write!Byte(Word(0x27FFCE3), firmware.user_settings.scr_y2);

        tcm.direct_boot();
    }

    @property
    static Architecture architecture() {
        return Architecture.v5TE;
    }

    pragma(inline, true) void maybe_reload_instruction_block() {
        Word requested_instruction_block_address = regs[pc] & ~(INSTRUCTION_BLOCK_SIZE - 1);

        if (current_instruction_block_address != requested_instruction_block_address) {
            if (tcm.can_write_itcm(requested_instruction_block_address)) {
                scheduler.tick(1);
                instruction_block = tcm.read_itcm_instruction(requested_instruction_block_address);
            } else {
                instruction_block = mem.read_instruction9(regs[pc] & ~(INSTRUCTION_BLOCK_SIZE - 1));
            }

            current_instruction_block_address = requested_instruction_block_address;
        }
    }

    bool first_fetch = true;
    pragma(inline, true) T fetch(T)() {
        if (!first_fetch && regs[pc] == 0) error_arm7("arm7 branched to 0");
        first_fetch = false;

        if ((regs[pc] & (INSTRUCTION_BLOCK_SIZE - 1)) == 0) {
            maybe_reload_instruction_block();
        }

        T opcode;

        static if (is(T == Word)) {
            opcode = arm_pipeline[0];
            arm_pipeline[0] = arm_pipeline[1];
            arm_pipeline[1] = instruction_block.code.read!T(regs[pc] & (INSTRUCTION_BLOCK_SIZE - 1));
            regs[pc] += 4;
        } else {
            opcode = thumb_pipeline[0];
            thumb_pipeline[0] = thumb_pipeline[1];
            thumb_pipeline[1] = instruction_block.code.read!T(regs[pc] & (INSTRUCTION_BLOCK_SIZE - 1));
            regs[pc] += 2;
        }
        
        return opcode;
    }

    pragma(inline, true) void execute(T)(T opcode) {
        version (ift) { IFTDebugger.instruction_start(); }

        static if (is(T == Word)) {
            auto cond = opcode[28..31];
            if (likely(check_cond(cond))) {
                auto entry = opcode[4..7] | (opcode[20..27] << 4);
                execute_arm!ARM946E_S.jumptable[entry](this, opcode);
            }
        }

        static if (is(T == Half)) {
            execute_thumb!ARM946E_S.jumptable[opcode >> 8](this, opcode);
        }

        version (ift) { IFTDebugger.instruction_end(); }
    }

    void run_instruction() {
        if (halted) return;
        
        if (!(cast(bool) get_cpsr()[7]) && interrupt9.irq_pending()) {
            raise_exception!(CpuException.IRQ);
        }
        
        version (release) {
        } else {
            // cpu_trace.capture();
        }
        
        if (num_log > 0) {
            log_state();
            num_log--;
        }
        
        if (instruction_set == InstructionSet.ARM) {
            Word opcode = fetch!Word();                
            if (opcode == 0) error_arm9("The ARM9 is probably executing data");
            execute!Word(opcode);
        } else {
            Half opcode = fetch!Half();
            if (opcode == 0) error_arm7("ARM9 is probably executing data");
            execute!Half(opcode);
        }
    }

    void log_state() {
        version (quiet) {
            return;
        } else {
            import std.format;
            import std.stdio;

            writef("LOG_ARM9 [%04d] ", num_log);
        
            if (get_flag(Flag.T)) write("THM ");
            else write("ARM ");

            write(format("0x%08x ", instruction_set == InstructionSet.ARM ? arm_pipeline[0] : thumb_pipeline[0]));
            
            for (int j = 0; j < 18; j++)
                write(format("%08x ", regs[j]));
            
            writef(" | ");
            writef(" %08x", get_reg(sp, MODE_SUPERVISOR));
            writeln();
        }
    }

    pragma(inline, true) Word get_reg(Reg id) {
        return get_reg__raw(id, &regs);
    }

    pragma(inline, true) void set_reg(Reg id, Word value) {
        set_reg__raw(id, value, &regs);
    }

    pragma(inline, true) Word get_reg__thumb(Reg id) {
        return regs[id];
    }

    pragma(inline, true) void set_reg__thumb(Reg id, Word value) {
        regs[id] = value;
    }

    pragma(inline, true) Word get_reg(Reg id, CpuMode mode) {
        bool is_banked = !(mode.REGISTER_UNIQUENESS.bit(id) & 1);

        if (!is_banked && (current_mode.REGISTER_UNIQUENESS.bit(id) & 1)) {
            return get_reg(id);
        } else {
            return get_reg__raw(id, cast(Word[18]*) (&register_file[mode.OFFSET]));
        }
    }

    pragma(inline, true) void set_reg(Reg id, Word value, CpuMode mode) {
        bool is_banked = !(mode.REGISTER_UNIQUENESS.bit(id) & 1);

        if (!is_banked && (current_mode.REGISTER_UNIQUENESS.bit(id) & 1)) {
            set_reg(id, value);
        } else {
            set_reg__raw(id, value, cast(Word[18]*) (&register_file[mode.OFFSET]));
        }
    }

    pragma(inline, true) Word get_reg__raw(Reg id, Word[18]* regs) {
        Word result;

        if (unlikely(id == pc)) {
            result = (*regs)[pc] - (instruction_set == InstructionSet.ARM ? 4 : 2);
        } else {
            result = (*regs)[id];
        }
        
        version (ift) { IFTDebugger.commit_reg_read(HwType.NDS9, id, current_mode, result); }
        return result;
    }

    pragma(inline, true) void set_reg__raw(Reg id, Word value, Word[18]* regs) {
        (*regs)[id] = value;

        if (id == pc) {
            (*regs)[pc] &= instruction_set == InstructionSet.ARM ? ~3 : ~1;
            maybe_reload_instruction_block();
            refill_pipeline();
        }

        version (ift) { IFTDebugger.commit_reg_write(HwType.NDS9, id, current_mode, value); }
    }

    pragma(inline, true) void align_pc(CpuMode mode) {
        regs[mode.OFFSET + pc] &= instruction_set == InstructionSet.ARM ? ~3 : ~1;
    }

    InstructionSet get_instruction_set() { 
        return instruction_set; 
    }

    Word get_pipeline_entry(int i) {
        return Word(
            instruction_set == InstructionSet.ARM ? 
            arm_pipeline[i] :
            thumb_pipeline[i]
        ); 
    }


    void enable() {
        this.halted = false;
    }

    void disable() {
        this.halted = true;
    }

    void halt() {
        this.halted = true;
    }

    void unhalt() {
        this.halted = false;
    }

    void set_mode(CpuMode new_mode)() {
        int mask;
        mask = current_mode.REGISTER_UNIQUENESS;
        
        // writeback
        for (int i = 0; i < 18; i++) {
            if (mask & 1) {
                register_file[MODE_USER.OFFSET + i] = regs[i];
            } else {
                register_file[current_mode.OFFSET + i] = regs[i];
            }

            mask >>= 1;
        }

        mask = new_mode.REGISTER_UNIQUENESS;
        for (int i = 0; i < 18; i++) {
            if (mask & 1) {
                regs[i] = register_file[MODE_USER.OFFSET + i];
            } else {
                regs[i] = register_file[new_mode.OFFSET + i];
            }

            mask >>= 1;
        }

        set_cpsr((get_cpsr() & 0xFFFFFFE0) | new_mode.CPSR_ENCODING);
        
        instruction_set = get_flag(Flag.T) ? InstructionSet.THUMB : InstructionSet.ARM;
        current_mode = new_mode;
    }

    Word get_cpsr() {
        return regs[16];
    }

    // user and system modes dont have spsr. spsr reads return cpsr.
    Word get_spsr() {
        if (current_mode == MODE_USER || current_mode == MODE_SYSTEM) {
            return get_cpsr();
        }

        return regs[17];
    }

    void set_cpsr(Word cpsr) {
        regs[16] = cpsr;
        instruction_set = get_flag(Flag.T) ? instruction_set.THUMB : instruction_set.ARM;
    }

    void set_spsr(Word spsr) {
        regs[17] = spsr;
    }

    void refill_pipeline() {
        // if (regs[pc] == 0x020e09e0) {
        //     log_arm9("sussy");
        //     Word arg0 = regs[0];
        //     Word arg1 = regs[1];

        //     log_arm7("sussy(%08x, %08x)", arg0, arg1);
        //     log_arm7("    arg0->0x16 = %04x", read_half(arg0 + 0x16));
        //     log_arm7("    arg0->0x26 = %02x", read_byte(arg0 + 0x26));
        //     log_arm7("    arg0->0x27 = %02x", read_byte(arg0 + 0x27));
        //     log_arm7("    arg0->0x28 = %02x", read_byte(arg0 + 0x28));
        //     log_arm7("    arg0->0x29 = %02x", read_byte(arg0 + 0x29));
        // }
        // if (regs[pc] == 0x20e0acc) {
        //     log_arm9("sussy's daddy");
        //     num_log = 20;
        // }



        if (regs[pc]  == 0x2098110) {
            log_arm7("magic michael: %x %x", arm9.regs[15], arm9.regs[14]);
                    for (int i = 0;  i < 100; i++) {
                log_arm7("    magic %x", read_word(arm9.regs[13] + i * 4));
            }
        }
        if (regs[pc]  == 0x2020608) {
            log_arm7("elector(%x %x)", arm9.regs[0], arm9.regs[14]);
        }
        if (regs[pc]  == 0x20ef22c) {
            log_arm7("magic michael caller: %x %x", arm9.regs[15], arm9.regs[14]);

        }
        if (regs[pc]  == 0x20f1eb8) {
            log_arm7("magic michael caller1: %x %x", arm9.regs[15], arm9.regs[0]);

        }
        if (regs[pc]  == 0x20cff24) {
            log_arm7("magic michael caller2: %x %x", arm9.regs[15], arm9.regs[0]);

        }
        if (regs[pc] == 0x020cf3a0) {
            log_arm7("oi1(%08x)", regs[0]);
        }

        if (regs[pc] == 0x020ef378) {
            log_arm7("should_i_go_back(%08x)", regs[0]);
        }

        if (regs[pc] == 0x02020608) {
            log_arm7("update_all_objects(%08x %08x)", regs[0], regs[14]);
            Word head = read_word(regs[0]);
            log_arm7("update_all_objects    head = %08x", head);
            Word curr = head;
            while (curr != 0) {
                log_arm7("update_all_objects    found element");
                Word data = read_word(curr);
                Word next = read_word(curr + 0x4);
                log_arm7("update_all_objects        data = %08x", data);
                log_arm7("update_all_objects        next = %08x", next);
                curr = next;
            }
        }

        if (regs[pc] == 0x0208a2c0) {
            log_arm7("mister_dicks(%08x)", regs[0]);
        }

        if (regs[pc] == 0x20cbed8) {
            log_arm7("aaa(%08x)", regs[0]);
                    for (int i = 0;  i < 100; i++) {
                log_arm7("    aaa %x", read_word(arm9.regs[13] + i * 4));
            }
        }

        if (regs[pc] == 0x208aa7c) {
            log_arm7("mariospos(%08x %08x)", regs[0], regs[1]);
            Word x = regs[0];
            log_arm7("mariospos    speeds: %x %x", read_word(x + 0x10), read_word(x + 0x14));
            log_arm7("mariospos    svar: %x", read_half(x + 0xc));
        }

        if (regs[pc] == 0x208ab68) {
        }

        if (regs[pc] == 0x020cdb90) {
            log_arm7("dicksfuckshti(%08x)", regs[0]);
        }

        if (regs[pc] == 0x0202066c) {
            log_arm7("caller33/.....(%08x %08x)", regs[0], regs[1]);
        }
        if (regs[pc] == 0x020cdc00) {
            // num_log = 20;
        }

        if (regs[pc] == 0x201f228) {
            log_arm7("calcspeed1 = %08x", regs[0]);
        }

        if (regs[pc] == 0x201f264) {
            log_arm7("calcspeed2 = %08x", regs[0]);
                    for (int i = 0;  i < 100; i++) {
                log_arm7("    aaa %x", read_word(arm9.regs[13] + i * 4));
            }
        }

        if (regs[pc] >= 0x0201f218 && regs[pc] <= 0x0201f268) {
            log_arm7("branch in hot range: %x %x", regs[pc], regs[lr]);
        }

        if (regs[pc] == 0x201ee54) {
            log_arm7("Returned: %x", regs[0]);
        }

        if (regs[pc] == 0x201ec50 && scheduler.get_current_time_relative_to_cpu() > 0x50000000) {
            log_arm7("Called: %x", regs[0]);
            // num_log = 30;
        }

        if (instruction_set == InstructionSet.ARM) {
            fetch!Word();
            fetch!Word();
        } else {
            fetch!Half();
            fetch!Half();
        }
    }

    bool check_cond(uint cond) {
        switch (cond) {
            case 0x0: return ( get_flag(Flag.Z));
            case 0x1: return (!get_flag(Flag.Z));
            case 0x2: return ( get_flag(Flag.C));
            case 0x3: return (!get_flag(Flag.C));
            case 0x4: return ( get_flag(Flag.N));
            case 0x5: return (!get_flag(Flag.N));
            case 0x6: return ( get_flag(Flag.V));
            case 0x7: return (!get_flag(Flag.V));
            case 0x8: return ( get_flag(Flag.C) && !get_flag(Flag.Z));
            case 0x9: return (!get_flag(Flag.C) ||  get_flag(Flag.Z));
            case 0xA: return ( get_flag(Flag.N) ==  get_flag(Flag.V));
            case 0xB: return ( get_flag(Flag.N) !=  get_flag(Flag.V));
            case 0xC: return (!get_flag(Flag.Z) && (get_flag(Flag.N) == get_flag(Flag.V)));
            case 0xD: return ( get_flag(Flag.Z) || (get_flag(Flag.N) != get_flag(Flag.V)));
            case 0xE: return true;
            case 0xF: return true;

            default: assert(0);
        }
    }

    void raise_exception(CpuException exception)() {
        // interrupts not allowed if the cpu itself has interrupts disabled.
        Word cpsr = regs[16];

        if ((exception == CpuException.IRQ && cpsr[7]) ||
            (exception == CpuException.FIQ && cpsr[6])) {
            return;
        }

        enum mode = get_mode_from_exception!(exception);

        register_file[mode.OFFSET + 14] = regs[pc] - 2 * (get_flag(Flag.T) ? 2 : 4);
        if (exception == CpuException.IRQ) {
            register_file[mode.OFFSET + 14] += 4; // in an IRQ, the linkage register must point to the next instruction + 4
        }

        // register_file[mode.OFFSET + 17] = cpsr;
        register_file[mode.OFFSET + 17] = cpsr;
        // writefln("setting SPSR to %x", register_file[mode.OFFSET + 17]);
        set_mode!(mode);
        cpsr = get_cpsr();

        cpsr |= (1 << 7); // disable normal interrupts

        static if (exception == CpuException.Reset || exception == CpuException.FIQ) {
            cpsr |= (1 << 6); // disable fast interrupts
        }
        regs[16] = cpsr;

        regs[pc] = get_address_from_exception!(exception);
        maybe_reload_instruction_block();

        set_flag(Flag.T, false);
        
        refill_pipeline();
        halted = false;
    }

    static uint get_address_from_exception(CpuException exception)() {
        final switch (exception) {
            case CpuException.Reset:             return 0xFFFF_0000;
            case CpuException.Undefined:         return 0xFFFF_0004;
            case CpuException.SoftwareInterrupt: return 0xFFFF_0008;
            case CpuException.PrefetchAbort:     return 0xFFFF_000C;
            case CpuException.DataAbort:         return 0xFFFF_0010;
            case CpuException.IRQ:               return 0xFFFF_0018;
            case CpuException.FIQ:               return 0xFFFF_001C;
        }
    }

    static CpuMode get_mode_from_exception(CpuException exception)() {
        final switch (exception) {
            case CpuException.Reset:             return MODE_SUPERVISOR;
            case CpuException.Undefined:         return MODE_UNDEFINED;
            case CpuException.SoftwareInterrupt: return MODE_SUPERVISOR;
            case CpuException.PrefetchAbort:     return MODE_ABORT;
            case CpuException.DataAbort:         return MODE_ABORT;
            case CpuException.IRQ:               return MODE_IRQ;
            case CpuException.FIQ:               return MODE_FIQ;
        }
    }

    static string get_exception_name(CpuException exception)() {
        switch (exception) {
            case CpuException.Reset:             return "RESET";
            case CpuException.Undefined:         return "UNDEFINED";
            case CpuException.SoftwareInterrupt: return "SWI";
            case CpuException.PrefetchAbort:     return "PREFETCH ABORT";
            case CpuException.DataAbort:         return "DATA ABORT";
            case CpuException.IRQ:               return "IRQ";
            case CpuException.FIQ:               return "FIQ";
        }
    }

    void set_flag(Flag flag, bool value) {
        Word cpsr = get_cpsr();

        if (sticky_flag(flag)) {
            cpsr[flag] |= value;
        } else {
            cpsr[flag] = value;
        }

        set_cpsr(cpsr);

        if (flag == Flag.T) {
            instruction_set = value ? InstructionSet.THUMB : InstructionSet.ARM;
        }
    }

    bool sticky_flag(Flag flag) {
        return flag == Flag.Q;
    }

    bool get_flag(Flag flag) {
        return cast(bool) get_cpsr()[flag];
    }

    void run_idle_cycle() {
        // TODO: replace with proper idling that actually takes up cpu cycles
    }

    bool in_a_privileged_mode() {
        return current_mode != MODE_USER;
    }

    void update_mode() {
        int mode_bits = get_cpsr()[0..4];
        static foreach (i; 0 .. 7) {
            if (MODES[i].CPSR_ENCODING == mode_bits) {
                set_mode!(MODES[i]);
            }
        }
    }

    bool has_spsr() {
        return !(current_mode == MODE_USER || current_mode == MODE_SYSTEM);
    }

    T internal_read(T)(Word address) {
        T result;
        if      (tcm.can_read_itcm(address)) { scheduler.tick(1); result = tcm.read_itcm!T(address); }
        else if (tcm.can_read_dtcm(address)) { scheduler.tick(1); result = tcm.read_dtcm!T(address); }
        
        else {
            static if (is(T == Word)) result = mem.read_data_word9(address);
            static if (is(T == Half)) result = mem.read_data_half9(address);
            static if (is(T == Byte)) result = mem.read_data_byte9(address);
        }

        for (int i = 0; i < T.sizeof; i++) {
            version (ift) { IFTDebugger.commit_mem_read(HwType.NDS9, address + i, Word(result.get_byte(i))); }
        }
        return result;
    }

    void internal_write(T)(Word address, T value) {
        if (tcm.can_write_itcm(address)) { scheduler.tick(1); tcm.write_itcm!T(address, value); return; }
        if (tcm.can_write_dtcm(address)) { scheduler.tick(1); tcm.write_dtcm!T(address, value); return; }
        
        static if (is(T == Word)) mem.write_data_word9(address, value);
        static if (is(T == Half)) mem.write_data_half9(address, value);
        static if (is(T == Byte)) mem.write_data_byte9(address, value);

        for (int i = 0; i < T.sizeof; i++) {
            version (ift) { IFTDebugger.commit_mem_write(HwType.NDS9, address + i, Word(value.get_byte(i))); }
        }
    }

    Word read_word(Word address) { return internal_read!Word(address); }
    Half read_half(Word address) { return internal_read!Half(address); }
    Byte read_byte(Word address) { return internal_read!Byte(address); }

    void write_word(Word address, Word value) { internal_write!Word(address, value); }
    void write_half(Word address, Half value) { internal_write!Half(address, value); }
    void write_byte(Word address, Byte value) { internal_write!Byte(address, value); }
}