module emu.hw.cpu.jumptable.jumptable_thumb;

import emu.hw.cpu;
import emu.hw.memory;

import util;

import core.bitop;

template execute_thumb(T : ArmCPU) {
    alias JumptableEntry = void function(T cpu, Half opcode);

    static void create_conditional_branch(int cond)(T cpu, Half opcode) {
        if (cpu.check_cond(cond)) {
            cpu.set_reg(pc, cpu.get_reg(pc) + (cast(s8)(opcode & 0xFF)) * 2);
        }
    }

    static void create_add_sub_mov_cmp(int op, Reg rd)(T cpu, Half opcode) {
        Word immediate = opcode[0..7];
        Word operand   = cpu.get_reg(rd);

        final switch (op) {
            case 0b00: cpu.mov(rd, immediate); break;
            case 0b01: cpu.cmp(rd, operand, immediate); break;
            case 0b10: cpu.add(rd, operand, immediate); break;
            case 0b11: cpu.sub(rd, operand, immediate); break;
        }
    }

    static void create_add_sub_immediate(int op)(T cpu, Half opcode) {
        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Word operand   = cpu.get_reg(rn);
        Word immediate = opcode[6..8];

        final switch (op) {
            case 0b0: cpu.add(rd, operand, immediate); break;
            case 0b1: cpu.sub(rd, operand, immediate); break;
        }
    }

    static void create_add_sub(int op)(T cpu, Half opcode) {
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

    static void create_branch_exchange_with_link(T cpu, Half opcode) {
        Word offset = opcode[0..10] * 2;
        auto next_pc = cpu.get_reg(pc) - 2;

        cpu.set_flag(Flag.T, false);
        cpu.set_reg(pc, (cpu.get_reg(lr) + offset) & ~3);
        cpu.set_reg(lr, next_pc | 1);
    }

    static void create_branch_with_link(bool is_first_instruction)(T cpu, Half opcode) {
        static if (is_first_instruction) {
            Word offset   = opcode[0..10];
            auto extended = sext_32(offset, 11);
            cpu.set_reg(lr, cpu.get_reg(pc) + (extended << 12));
        } else {
            auto next_pc = cpu.get_reg(pc) - 2;
            auto offset  = opcode[0..10] << 1;
            cpu.set_reg(pc, cpu.get_reg(lr) + offset);
            cpu.set_reg(lr, next_pc | 1);
        }
    }

    static void create_branch_exchange(T cpu, Half opcode) {
        if (v5TE!T && opcode[7]) {
            Reg rm = opcode[3..5];
            Word address = cpu.get_reg(rm);
            auto next_pc = cpu.get_reg(pc) - 2;

            cpu.set_flag(Flag.T, address[0]);
            cpu.set_reg(lr, next_pc | 1);
            cpu.set_reg(pc, address);
        } else {
            Reg rm = opcode[3..6];

            Word address = cpu.get_reg(rm);
            cpu.set_flag(Flag.T, cast(bool) (address & 1));
            cpu.set_reg(pc, address);
        }
    }

    static void create_pc_relative_load(Reg reg)(T cpu, Half opcode) {
        auto offset  = opcode[0..7] * 4;
        auto address = (cpu.get_reg(pc) + offset) & ~3;

        cpu.ldr(reg, address);
    }

    static void create_stm(Reg base)(T cpu, Half opcode) {
        Word start_address = cpu.get_reg(base);
        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        if (register_list == 0) {
            cpu.write_word(start_address, cpu.get_reg(pc) + 2, access_type);
            if (v4T!T) cpu.set_reg(base, start_address + 0x40);
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

        if (v5TE!T) cpu.set_reg(base, writeback_value);

        cpu.set_pipeline_access_type(AccessType.NONSEQUENTIAL);
    }

    static void create_ldm(Reg base)(T cpu, Half opcode) {
        Word start_address = cpu.get_reg(base);
        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        if (register_list == 0) {
            if (v4T!T) cpu.set_reg(pc, cpu.read_word(start_address, access_type));
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
        if (v4T!T && !base_in_register_list) {
            cpu.set_reg(base, current_address);
        }

        if (v5TE!T && base_in_register_list) {
            if (register_list >= 1 << base) {
                cpu.set_reg(base, current_address);
            }
        }
        
        cpu.run_idle_cycle();
    }

    static void create_load_store_immediate_offset(bool is_load, bool is_byte)(T cpu, Half opcode) {
        Reg rd      = opcode[0..2];
        Reg rn      = opcode[3..5];
        Word offset = opcode[6..10];
        Word base   = cpu.get_reg(rn);

        static if ( is_load &&  is_byte) cpu.ldrb(rd, base + offset);
        static if ( is_load && !is_byte) cpu.ldr (rd, base + offset * 4);
        static if (!is_load &&  is_byte) cpu.strb(rd, base + offset);
        static if (!is_load && !is_byte) cpu.str (rd, base + offset * 4);
    }

    static void create_load_store_register_offset(int op)(T cpu, Half opcode) {
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

    static void create_alu_high_registers(int op)(T cpu, Half opcode) {

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

    static void create_add_sp_pc_relative(Reg rd, bool is_sp)(T cpu, Half opcode) {
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

    static void create_logical_shift(bool is_lsr)(T cpu, Half opcode) {
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
        auto offset = sext_32(Word(opcode[0..10] * 2), 12);
        cpu.set_reg(pc, cpu.get_reg(pc) + offset);
    }

    static void create_sp_relative_load_store(Reg rd, bool is_load)(T cpu, Half opcode) {
        Word offset  = opcode[0..7] * 4;
        Word address = cpu.get_reg(sp) + offset;
        static if (is_load) cpu.ldr(rd, address);
        else                cpu.str(rd, address);
    }

    static void create_half_access(bool is_load)(T cpu, Half opcode) {
        Reg  rd      = opcode[0..2];
        Reg  rn      = opcode[3..5];
        Word offset  = opcode[6..10] * 2;
        Word address = cpu.get_reg(rn) + offset;
        static if (is_load) cpu.ldrh(rd, address);
        else                cpu.strh(rd, address);
    }

    static void create_pop(bool lr_included)(T cpu, Half opcode) {
        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        Word current_address = cpu.get_reg(sp);

        if (register_list == 0 && !lr_included) {
            if (v4T!T) cpu.set_reg(pc, cpu.read_word(current_address, access_type));
            cpu.set_reg(sp, current_address + 0x40);
            return;
        }

        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.set_reg(i, cpu.read_word(current_address & ~3, access_type));

                current_address += 4;

                access_type = AccessType.SEQUENTIAL;
            }
        }

        cpu.set_pipeline_access_type(AccessType.NONSEQUENTIAL);

        static if (lr_included) {
            Word value = cpu.read_word(current_address & ~3, access_type);
            static if (v5TE!T) cpu.set_flag(Flag.T, value[0]);
            cpu.set_reg(pc, value);

            current_address += 4;
        }

        cpu.set_reg(sp, current_address);
    }

    static void create_push(bool lr_included)(T cpu, Half opcode) {
        auto register_list = opcode[0..7];
        AccessType access_type = AccessType.NONSEQUENTIAL;

        Word current_address = cpu.get_reg(sp);

        if (register_list == 0 && !lr_included) {
            cpu.write_word(current_address, cpu.get_reg(pc) + 2, access_type);
            if (v4T!T) cpu.set_reg(sp, current_address + 0x40);
            return;
        }

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

    static void create_undefined_instruction(T cpu, Half opcode) {      
        log_unimplemented("Tried to execute undefined THUMB instruction: %04x", opcode);
    }

    static JumptableEntry[256] create_jumptable() {
        JumptableEntry[256] jumptable;

        static foreach (entry; 0 .. 256) {{
            enum Half static_opcode = cast(Half) entry;

            if ((entry & 0b1111_1111) == 0b1101_1111) {
                jumptable[entry] = &create_swi;
            } else

            if ((entry & 0b1110_0000) == 0b0010_0000) {
                enum op = static_opcode[3..4];
                enum rd = static_opcode[0..2];
                jumptable[entry] = &create_add_sub_mov_cmp!(op, rd);
            } else

            if ((entry & 0b1111_1100) == 0b0001_1000) {
                enum op = static_opcode[1];
                jumptable[entry] = &create_add_sub!op;
            } else

            if ((entry & 0b1111_0000) == 0b1101_0000) {
                enum cond = static_opcode[0..3];
                jumptable[entry] = &create_conditional_branch!cond;
            } else

            if ((entry & 0b1111_1111) == 0b0100_0111) {
                jumptable[entry] = &create_branch_exchange;
            } else

            if ((entry & 0b1111_1000) == 0b0100_1000) {
                enum reg = static_opcode[0..2];
                jumptable[entry] = &create_pc_relative_load!reg;
            } else

            if ((entry & 0b1111_0000) == 0b1111_0000) {
                enum is_first_instruction = !static_opcode[3];
                jumptable[entry] = &create_branch_with_link!is_first_instruction;
            } else

            if (v5TE!T && (entry & 0b1111_1000) == 0b1110_1000) {
                jumptable[entry] = &create_branch_exchange_with_link;
            } else

            if ((entry & 0b1111_1100) == 0b0100_0000) {
                jumptable[entry] = &create_full_alu;
            } else

            if ((entry & 0b1111_1000) == 0b1100_0000) {
                enum base = static_opcode[0..2];
                jumptable[entry] = &create_stm!base;
            } else

            if ((entry & 0b1111_1000) == 0b1100_1000) {
                enum base = static_opcode[0..2];
                jumptable[entry] = &create_ldm!base;
            } else

            if ((entry & 0b1111_1100) == 0b0001_1100) {
                enum op = static_opcode[1];
                jumptable[entry] = &create_add_sub_immediate!op;
            } else

            if ((entry & 0b1110_0000) == 0b0110_0000) {
                enum is_load = static_opcode[3];
                enum is_byte = static_opcode[4];
                jumptable[entry] = &create_load_store_immediate_offset!(is_load, is_byte);
            } else

            if ((entry & 0b1111_1100) == 0b0100_0100) {
                enum op = static_opcode[0..1];
                jumptable[entry] = &create_alu_high_registers!op;
            } else

            if ((entry & 0b1111_0000) == 0b1010_0000) {
                enum rd    = static_opcode[0..2];
                enum is_sp = static_opcode[3];
                jumptable[entry] = &create_add_sp_pc_relative!(rd, is_sp);
            } else

            if ((entry & 0b1111_0000) == 0b0000_0000) {
                enum is_lsr = static_opcode[3];
                jumptable[entry] = &create_logical_shift!is_lsr;
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
                enum op = static_opcode[1..3];
                jumptable[entry] = &create_load_store_register_offset!op;
            } else

            if ((entry & 0b1111_0000) == 0b1001_0000) {
                enum rd      = static_opcode[0..2];
                enum is_load = static_opcode[3];
                jumptable[entry] = &create_sp_relative_load_store!(rd, is_load);
            } else

            if ((entry & 0b1111_0000) == 0b1000_0000) {
                enum is_load = static_opcode[3];
                jumptable[entry] = &create_half_access!is_load;
            } else

            if ((entry & 0b1111_1110) == 0b1011_1100) {
                enum lr_included = static_opcode[0];
                jumptable[entry] = &create_pop!lr_included;
            } else

            if ((entry & 0b1111_1110) == 0b1011_0100) {
                enum lr_included = static_opcode[0];
                jumptable[entry] = &create_push!lr_included;
            } else

            if ((entry & 0b1111_1000) == 0b1000_0000) {
                jumptable[entry] = &create_store_half;
            } else

            jumptable[entry] = &create_undefined_instruction;
        }}

        return jumptable;
    }

    static JumptableEntry[256] jumptable = create_jumptable();
}