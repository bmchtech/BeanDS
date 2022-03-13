module core.hw.cpu.jumptable.jumptable_thumb;

import core.hw.cpu;
import core.hw.memory;

import util;

import core.bitop;

template execute_thumb(T : ArmCPU) {
    alias JumptableEntry = void function(T cpu, Half opcode);

    static void create_conditional_branch(Half static_opcode)(T cpu, Half opcode) {
        enum cond = static_opcode[0..3];
        if (cpu.check_cond(cond)) {
            cpu.set_reg(pc, cpu.get_reg(pc) + (cast(s8)(opcode & 0xFF)) * 2);
        }
    }

    static void create_add_sub_mov_cmp(Half static_opcode)(T cpu, Half opcode) {
        enum op = static_opcode[3..4];
        enum rd = static_opcode[0..2];

        Word immediate = opcode[0..7];
        Word operand   = cpu.get_reg(rd);

        final switch (op) {
            case 0b00: cpu.mov(rd, immediate); break;
            case 0b01: cpu.cmp(rd, operand, immediate); break;
            case 0b10: cpu.add(rd, operand, immediate); break;
            case 0b11: cpu.sub(rd, operand, immediate); break;
        }
    }

    static void create_add_sub_immediate(Half static_opcode)(T cpu, Half opcode) {
        enum op = static_opcode[1];

        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Word operand   = cpu.get_reg(rn);
        Word immediate = opcode[6..8];

        final switch (op) {
            case 0b0: cpu.add(rd, operand, immediate); break;
            case 0b1: cpu.sub(rd, operand, immediate); break;
        }
    }

    static void create_add_sub(Half static_opcode)(T cpu, Half opcode) {
        enum op = static_opcode[1];

        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Reg rm = opcode[6..8];
        Word operand1 = cpu.get_reg(rn);
        Word operand2 = cpu.get_reg(rm);

        final switch (op) {
            case 0: cpu.add(rd, operand1, operand2); break;
            case 1: cpu.sub(rd, operand1, operand2); break;
        }
    }

    static void create_full_alu(T cpu, Half opcode) {
        auto rd = opcode[0..2];
        auto rm = opcode[3..5];
        auto op = opcode[6..9];
        Word operand1 = cpu.get_reg(rd);
        Word operand2 = cpu.get_reg(rm);

        final switch (op) {
            case  0: cpu.and(rd, operand1, operand2); break;
            case  1: cpu.eor(rd, operand1, operand2); break; 
            case  2: cpu.lsl(rd, operand1, operand2 & 0xFF); break;
            case  3: cpu.lsr(rd, operand1, operand2 & 0xFF); break;
            case  4: cpu.asr(rd, operand1, operand2 & 0xFF); break; 
            case  5: cpu.adc(rd, operand1, operand2); break;
            case  6: cpu.sbc(rd, operand1, operand2); break;
            case  7: cpu.ror(rd, operand1, operand2 & 0xFF); cpu.run_idle_cycle(); break;
            case  8: cpu.tst(rd, operand1, operand2); break;
            case  9: cpu.neg(rd, operand2); break;
            case 10: cpu.cmp(rd, operand1, operand2); break;
            case 11: cpu.cmn(rd, operand1, operand2); break;
            case 12: cpu.orr(rd, operand1, operand2); break;
            case 13: cpu.mul(rd, operand1, operand2); break;
            case 14: cpu.bic(rd, operand1, operand2); break;
            case 15: cpu.mvn(rd, operand2); break;
        }
    }

    static void create_long_branch(Half static_opcode)(T cpu, Half opcode) {
        enum is_first_instruction = !static_opcode[3];
        
        static if (is_first_instruction) {
            auto offset   = opcode[0..10];
            auto extended = cpu.sext_32(offset, 11);
            cpu.set_reg(lr, cpu.get_reg(pc) + (extended << 12));
        } else {
            auto next_pc = cpu.get_reg(pc) - 2;
            auto offset  = opcode[0..10] << 1;
            cpu.set_reg(pc, cpu.get_reg(lr) + offset);
            cpu.set_reg(lr, next_pc | 1);
        }
    }

    static void create_branch_exchange(T cpu, Half opcode) {
        Reg rm = opcode[3..6];

        Word address = cpu.get_reg(rm);
        cpu.set_flag(Flag.T, cast(bool) (address & 1));
        cpu.set_reg(pc, address);
    }

    static void create_pc_relative_load(Half static_opcode)(T cpu, Half opcode) {
        enum reg = static_opcode[0..2];

        auto offset  = opcode[0..7] * 4;
        auto address = (cpu.get_reg(pc) + offset) & ~3;

        cpu.ldr(reg, address);
    }

    static void create_stm(Half static_opcode)(T cpu, Half opcode) {
        enum base = static_opcode[0..2];
        
        Word start_address = cpu.get_reg(base);
        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        if (register_list == 0) {
            cpu.write_word(start_address, cpu.get_reg(pc) + 2, access_type);
            cpu.set_reg(base, start_address + 0x40);
            return;
        }

        auto writeback_value = start_address + popcnt(register_list) * 4;
        bool is_first_access = true;

        Word current_address = start_address;
        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.write_word(current_address, cpu.get_reg(i), access_type);
                access_type = AccessType.SEQUENTIAL;
                current_address += 4;

                if (is_first_access) cpu.set_reg(base, writeback_value);
                is_first_access = false;
            }
        }

        cpu.set_pipeline_access_type(AccessType.NONSEQUENTIAL);
    }

    static void create_ldm(Half static_opcode)(T cpu, Half opcode) {
        enum base = static_opcode[0..2];
        
        Word start_address = cpu.get_reg(base);
        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        if (register_list == 0) {
            cpu.set_reg(pc, cpu.read_word(start_address, access_type));
            cpu.set_reg(base, start_address + 0x40);
            return;
        }
        
        Word current_address = start_address;

        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.set_reg(i, cpu.read_word(current_address, access_type));
                access_type = AccessType.SEQUENTIAL;
                current_address += 4;
            }
        }

        bool base_in_register_list = register_list[base];
        if (!base_in_register_list) {
            cpu.set_reg(base, current_address);
        }
        
        cpu.run_idle_cycle();
    }

    static void create_load_store_immediate_offset(Half static_opcode)(T cpu, Half opcode) {
        enum is_load = static_opcode[3];
        enum is_byte = static_opcode[4];

        Reg rd      = opcode[0..2];
        Reg rn      = opcode[3..5];
        Word offset = opcode[6..10];
        Word base   = cpu.get_reg(rn);

        static if ( is_load &&  is_byte) cpu.ldrb(rd, base + offset);
        static if ( is_load && !is_byte) cpu.ldr (rd, base + offset * 4);
        static if (!is_load &&  is_byte) cpu.strb(rd, base + offset);
        static if (!is_load && !is_byte) cpu.str (rd, base + offset * 4);
    }

    static void create_load_store_register_offset(Half static_opcode)(T cpu, Half opcode) {
        enum op = static_opcode[1..3];

        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Reg rm = opcode[6..8];
        Word address = cpu.get_reg(rm) + cpu.get_reg(rn);

        enum cpu_func = [
            &str!T,
            &strh!T,
            &strb!T,
            &ldrsb!T,
            &ldr!T,
            &ldrh!T,
            &ldrb!T,
            &ldrsh!T
        ][op];

        cpu_func(cpu, rd, address);
    }

    static void create_alu_high_registers(Half static_opcode)(T cpu, Half opcode) {
        enum op = static_opcode[0..1];

        Reg rm = opcode[3..6];
        Reg rd = opcode[0..2] | (opcode[7] << 3);
        Word operand1 = cpu.get_reg(rd);
        Word operand2 = cpu.get_reg(rm);

        final switch (op) {
            case 0b00: cpu.add(rd, operand1, operand2, true, false); break;
            case 0b01: cpu.cmp(rd, operand1, operand2); break;
            case 0b10: cpu.mov(rd, operand2, false); break;
        }
    }

    static void create_add_sp_pc_relative(Half static_opcode)(T cpu, Half opcode) {
        enum rd    = static_opcode[0..2];
        enum is_sp = static_opcode[3];

        Word immediate = opcode[0..7] << 2;
        static if ( is_sp) Word base = cpu.get_reg(sp);
        static if (!is_sp) Word base = cpu.get_reg(pc) & ~3;

        cpu.set_reg(rd, base + immediate);
    }

    static void create_modify_sp(T cpu, Half opcode) {
        Word immediate      = opcode[0..6] << 2;
        bool is_subtraction = opcode [7];
        
        if (is_subtraction) cpu.set_reg(sp, cpu.get_reg(sp) - immediate);
        else                cpu.set_reg(sp, cpu.get_reg(sp) + immediate);
    }

    static void create_logical_shift(Half static_opcode)(T cpu, Half opcode) {
        enum is_lsr = static_opcode[3];

        Reg rd     = opcode[0..2];
        Reg rm     = opcode[3..5];
        auto shift = opcode[6..10];

        auto operand = cpu.get_reg(rm);

        if (shift == 0) {
            static if (!is_lsr) {
                cpu.set_reg(rd, cpu.get_reg(rm));
                return;
            } else {
                shift = 32;
            }
        }

        static if (is_lsr) cpu.lsr(rd, operand, shift);
        else               cpu.lsl(rd, operand, shift);
        
        cpu.run_idle_cycle();
    }

    static void create_arithmetic_shift(T cpu, Half opcode) {
        Reg rd     = opcode[0..2];
        Reg rm     = opcode[3..5];
        auto shift = opcode[6..10];
        if (shift == 0) shift = 32;

        auto operand = cpu.get_reg(rm);
        cpu.asr(rd, operand, shift);
        
        cpu.run_idle_cycle();
    }

    static void create_unconditional_branch(T cpu, Half opcode) {
        auto offset = cpu.sext_32(opcode[0..10] * 2, 12);
        cpu.set_reg(pc, cpu.get_reg(pc) + offset);
    }

    static void create_sp_relative_load_store(Half static_opcode)(T cpu, Half opcode) {
        enum rd      = static_opcode[0..2];
        enum is_load = static_opcode[3];

        Word offset  = opcode[0..7] * 4;
        Word address = cpu.get_reg(sp) + offset;
        static if (is_load) cpu.ldr(rd, address);
        else                cpu.str(rd, address);
    }

    static void create_half_access(Half static_opcode)(T cpu, Half opcode) {
        enum is_load = static_opcode[3];

        Reg  rd      = opcode[0..2];
        Reg  rn      = opcode[3..5];
        Word offset  = opcode[6..10] * 2;
        Word address = cpu.get_reg(rn) + offset;
        static if (is_load) cpu.ldrh(rd, address);
        else                cpu.strh(rd, address);
    }

    static void create_pop(Half static_opcode)(T cpu, Half opcode) {
        enum lr_included = static_opcode[0];

        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        Word current_address = cpu.get_reg(sp);
        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.set_reg(i, cpu.read_word(current_address & ~3, access_type));

                current_address += 4;

                access_type = AccessType.SEQUENTIAL;
            }
        }

        cpu.set_pipeline_access_type(AccessType.NONSEQUENTIAL);

        static if (lr_included) {
            cpu.set_reg(pc, cpu.read_word(current_address & ~3, access_type));

            current_address += 4;
        }

        cpu.set_reg(sp, current_address);
    }

    static void create_push(Half static_opcode)(T cpu, Half opcode) {
        enum lr_included = static_opcode[0];

        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        Word current_address = cpu.get_reg(sp);

        static if (lr_included) {
            current_address -= 4;
            cpu.write_word(current_address & ~3, cpu.get_reg(lr), access_type);
        }

        for (int i = 7; i >= 0; i--) {
            if (register_list[i]) {
                current_address -= 4;
                cpu.write_word(current_address & ~3, cpu.get_reg(i), access_type);

                access_type = AccessType.SEQUENTIAL;
            }
        }

        cpu.set_pipeline_access_type(AccessType.NONSEQUENTIAL);

        cpu.set_reg(sp, current_address);
    }

    static void create_store_half(T cpu, Half opcode) {
        Reg rd      = opcode[0..2];
        Reg rn      = opcode[3..5];
        Word offset = opcode[6..10] * 2;

        cpu.strh(rd, cpu.get_reg(rn) + offset);
    }

    static void create_swi(T cpu, Half opcode) {
        cpu.swi();
    }

    static void create_nop(T cpu, Half opcode) {}

    static JumptableEntry[256] create_jumptable() {
        JumptableEntry[256] jumptable;

        static foreach (entry; 0 .. 256) {{
            enum Half static_opcode = cast(Half) entry;

            if ((entry & 0b1111_1111) == 0b1101_1111) {
                jumptable[entry] = &create_swi;
            } else

            if ((entry & 0b1110_0000) == 0b0010_0000) {
                jumptable[entry] = &create_add_sub_mov_cmp!static_opcode;
            } else

            if ((entry & 0b1111_1100) == 0b0001_1000) {
                jumptable[entry] = &create_add_sub!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b1101_0000) {
                jumptable[entry] = &create_conditional_branch!static_opcode;
            } else

            if ((entry & 0b1111_1111) == 0b0100_0111) {
                jumptable[entry] = &create_branch_exchange;
            } else

            if ((entry & 0b1111_1000) == 0b0100_1000) {
                jumptable[entry] = &create_pc_relative_load!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b1111_0000) {
                jumptable[entry] = &create_long_branch!static_opcode;
            } else

            if ((entry & 0b1111_1100) == 0b0100_0000) {
                jumptable[entry] = &create_full_alu;
            } else

            if ((entry & 0b1111_1000) == 0b1100_0000) {
                jumptable[entry] = &create_stm!static_opcode;
            } else

            if ((entry & 0b1111_1000) == 0b1100_1000) {
                jumptable[entry] = &create_ldm!static_opcode;
            } else

            if ((entry & 0b1111_1100) == 0b0001_1100) {
                jumptable[entry] = &create_add_sub_immediate!static_opcode;
            } else

            if ((entry & 0b1110_0000) == 0b0110_0000) {
                jumptable[entry] = &create_load_store_immediate_offset!static_opcode;
            } else

            if ((entry & 0b1111_1100) == 0b0100_0100) {
                jumptable[entry] = &create_alu_high_registers!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b1010_0000) {
                jumptable[entry] = &create_add_sp_pc_relative!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b0000_0000) {
                jumptable[entry] = &create_logical_shift!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b001_0000) {
                jumptable[entry] = &create_arithmetic_shift;
            } else

            if ((entry & 0b1111_1111) == 0b1011_0000) {
                jumptable[entry] = &create_modify_sp;
            } else

            if ((entry & 0b1111_1000) == 0b1110_0000) {
                jumptable[entry] = &create_unconditional_branch;
            } else

            if ((entry & 0b1111_0000) == 0b0101_0000) {
                jumptable[entry] = &create_load_store_register_offset!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b1001_0000) {
                jumptable[entry] = &create_sp_relative_load_store!static_opcode;
            } else

            if ((entry & 0b1111_0000) == 0b1000_0000) {
                jumptable[entry] = &create_half_access!static_opcode;
            } else

            if ((entry & 0b1111_1110) == 0b1011_1100) {
                jumptable[entry] = &create_pop!static_opcode;
            } else

            if ((entry & 0b1111_1110) == 0b1011_0100) {
                jumptable[entry] = &create_push!static_opcode;
            } else

            if ((entry & 0b1111_1000) == 0b1000_0000) {
                jumptable[entry] = &create_store_half;
            } else

            jumptable[entry] = &create_nop;
        }}

        return jumptable;
    }

    static JumptableEntry[256] jumptable = create_jumptable();
}