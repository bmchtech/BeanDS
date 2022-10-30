module emu.hw.cpu.jumptable.jumptable_thumb;

import core.bitop;
import emu.hw.cpu;
import emu.hw.memory;
import util;

template execute_thumb(T : ArmCPU) {
    alias JumptableEntry = void function(T cpu, Half opcode);

    static void create_conditional_branch(int cond)(T cpu, Half opcode) {
        if (cpu.check_cond(cond)) {
            cpu.set_reg(pc, cpu.get_reg(pc) + (cast(s8)(opcode & 0xFF)) * 2);
        }
    }

    static void create_add_sub_mov_cmp(int op, Reg rd)(T cpu, Half opcode) {
        Word immediate = opcode[0..7];
        Word operand   = cpu.get_reg__thumb(rd);

        final switch (op) {
            case 0b00: cpu.mov!(T, true)(rd, immediate); break;
            case 0b01: cpu.cmp!(T, true)(rd, operand, immediate); break;
            case 0b10: cpu.add!(T, true)(rd, operand, immediate); break;
            case 0b11: cpu.sub!(T, true)(rd, operand, immediate); break;
        }
    }

    static void create_add_sub_immediate(int op)(T cpu, Half opcode) {
        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Word operand   = cpu.get_reg__thumb(rn);
        Word immediate = opcode[6..8];

        final switch (op) {
            case 0b0: cpu.add!(T, true)(rd, operand, immediate); break;
            case 0b1: cpu.sub!(T, true)(rd, operand, immediate); break;
        }
    }

    static void create_add_sub(int op)(T cpu, Half opcode) {
        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Reg rm = opcode[6..8];
        Word operand1 = cpu.get_reg__thumb(rn);
        Word operand2 = cpu.get_reg__thumb(rm);

        final switch (op) {
            case 0: cpu.add!(T, true)(rd, operand1, operand2); break;
            case 1: cpu.sub!(T, true)(rd, operand1, operand2); break;
        }
    }

    static void create_full_alu(T cpu, Half opcode) {
        auto rd = opcode[0..2];
        auto rm = opcode[3..5];
        auto op = opcode[6..9];
        Word operand1 = cpu.get_reg__thumb(rd);
        Word operand2 = cpu.get_reg__thumb(rm);

        final switch (op) {
            case  0: cpu.and!(T, true)(rd, operand1, operand2); break;
            case  1: cpu.eor!(T, true)(rd, operand1, operand2); break; 
            case  2: cpu.lsl!(T, true)(rd, operand1, operand2 & 0xFF); break;
            case  3: cpu.lsr!(T, true)(rd, operand1, operand2 & 0xFF); break;
            case  4: cpu.asr!(T, true)(rd, operand1, operand2 & 0xFF); break; 
            case  5: cpu.adc!(T, true)(rd, operand1, operand2); break;
            case  6: cpu.sbc!(T, true)(rd, operand1, operand2); break;
            case  7: cpu.ror!(T, true)(rd, operand1, operand2 & 0xFF); cpu.run_idle_cycle(); break;
            case  8: cpu.tst!(T, true)(rd, operand1, operand2); break;
            case  9: cpu.neg!(T, true)(rd, operand2); break;
            case 10: cpu.cmp!(T, true)(rd, operand1, operand2); break;
            case 11: cpu.cmn!(T, true)(rd, operand1, operand2); break;
            case 12: cpu.orr!(T, true)(rd, operand1, operand2); break;
            case 13: cpu.mul!(T, true)(rd, operand1, operand2); break;
            case 14: cpu.bic!(T, true)(rd, operand1, operand2); break;
            case 15: cpu.mvn!(T, true)(rd, operand2); break;
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
            Word address = cpu.get_reg__thumb(rm);
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

        cpu.ldr!(T, true)(reg, address);
    }

    static void create_stm(Reg base)(T cpu, Half opcode) {
        Word start_address = cpu.get_reg__thumb(base);
        auto register_list = opcode[0..7];

        if (register_list == 0) {
            cpu.write_word(start_address, cpu.get_reg(pc) + 2);
            if (v4T!T) cpu.set_reg__thumb(base, start_address + 0x40);
            return;
        }

        auto writeback_value = start_address + popcnt(register_list) * 4;
        bool is_first_access = true;

        Word current_address = start_address;
        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.write_word(current_address, cpu.get_reg__thumb(i));
                current_address += 4;

                static if (v4T!T) if (is_first_access) cpu.set_reg__thumb(base, writeback_value);
                is_first_access = false;
            }
        }

        static if (v5TE!T) cpu.set_reg__thumb(base, writeback_value);
    }

    static void create_ldm(Reg base)(T cpu, Half opcode) {
        Word start_address = cpu.get_reg__thumb(base);
        auto register_list = opcode[0..7];

        if (register_list == 0) {
            if (v4T!T) cpu.set_reg(pc, cpu.read_word(start_address));
            cpu.set_reg__thumb(base, start_address + 0x40);
            return;
        }
        
        Word current_address = start_address;

        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.set_reg__thumb(i, cpu.read_word(current_address));
                current_address += 4;
            }
        }

        bool base_in_register_list = register_list[base];
        if (!base_in_register_list) {
            cpu.set_reg__thumb(base, current_address);
        }
        
        cpu.run_idle_cycle();
    }

    static void create_load_store_immediate_offset(bool is_load, bool is_byte)(T cpu, Half opcode) {
        Reg rd      = opcode[0..2];
        Reg rn      = opcode[3..5];
        Word offset = opcode[6..10];
        Word base   = cpu.get_reg__thumb(rn);

        static if ( is_load &&  is_byte) cpu.ldrb!(T, true)(rd, base + offset);
        static if ( is_load && !is_byte) cpu.ldr !(T, true)(rd, base + offset * 4);
        static if (!is_load &&  is_byte) cpu.strb!(T, true)(rd, base + offset);
        static if (!is_load && !is_byte) cpu.str !(T, true)(rd, base + offset * 4);
    }

    static void create_load_store_register_offset(int op)(T cpu, Half opcode) {
        Reg rd = opcode[0..2];
        Reg rn = opcode[3..5];
        Reg rm = opcode[6..8];
        Word address = cpu.get_reg__thumb(rm) + cpu.get_reg__thumb(rn);

        enum cpu_func = [
            &str!(T, true),
            &strh!(T, true),
            &strb!(T, true),
            &ldrsb!(T, true),
            &ldr!(T, true),
            &ldrh!(T, true),
            &ldrb!(T, true),
            &ldrsh!(T, true)
        ][op];

        cpu_func(cpu, rd, address);
    }

    static void create_alu_high_registers(int op)(T cpu, Half opcode) {

        Reg rm = opcode[3..6];
        Reg rd = opcode[0..2] | (opcode[7] << 3);
        Word operand1 = cpu.get_reg(rd);
        Word operand2 = cpu.get_reg(rm);

        final switch (op) {
            case 0b00: cpu.add!(T, false)(rd, operand1, operand2, true, false); break;
            case 0b01: cpu.cmp!(T, false)(rd, operand1, operand2); break;
            case 0b10: cpu.mov!(T, false)(rd, operand2, false); break;
        }
    }

    static void create_add_sp_pc_relative(Reg rd, bool is_sp)(T cpu, Half opcode) {
        Word immediate = opcode[0..7] << 2;
        Word base;

        static if ( is_sp) base = cpu.get_reg(sp);
        static if (!is_sp) base = cpu.get_reg(pc) & ~3;

        cpu.set_reg__thumb(rd, base + immediate);
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

        auto operand = cpu.get_reg__thumb(rm);

        if (shift == 0) {
            static if (!is_lsr) {
                cpu.set_reg__thumb(rd, cpu.get_reg__thumb(rm));
                return;
            } else {
                shift = 32;
            }
        }

        static if (is_lsr) cpu.lsr!(T, true)(rd, operand, shift);
        else               cpu.lsl!(T, true)(rd, operand, shift);
        
        cpu.run_idle_cycle();
    }

    static void create_arithmetic_shift(T cpu, Half opcode) {
        Reg rd     = opcode[0..2];
        Reg rm     = opcode[3..5];
        auto shift = opcode[6..10];
        if (shift == 0) shift = 32;

        auto operand = cpu.get_reg__thumb(rm);
        cpu.asr!(T, true)(rd, operand, shift);
        
        cpu.run_idle_cycle();
    }

    static void create_unconditional_branch(T cpu, Half opcode) {
        auto offset = sext_32(Word(opcode[0..10] * 2), 12);
        cpu.set_reg(pc, cpu.get_reg(pc) + offset);
    }

    static void create_sp_relative_load_store(Reg rd, bool is_load)(T cpu, Half opcode) {
        Word offset  = opcode[0..7] * 4;
        Word address = cpu.get_reg(sp) + offset;
        static if (is_load) cpu.ldr!(T, true)(rd, address);
        else                cpu.str!(T, true)(rd, address);
    }

    static void create_half_access(bool is_load)(T cpu, Half opcode) {
        Reg  rd      = opcode[0..2];
        Reg  rn      = opcode[3..5];
        Word offset  = opcode[6..10] * 2;
        Word address = cpu.get_reg__thumb(rn) + offset;
        static if (is_load) cpu.ldrh!(T, true)(rd, address);
        else                cpu.strh!(T, true)(rd, address);
    }

    static void create_pop(bool lr_included)(T cpu, Half opcode) {
        auto register_list = opcode[0..7];

        Word current_address = cpu.get_reg(sp);

        if (register_list == 0 && !lr_included) {
            if (v4T!T) cpu.set_reg(pc, cpu.read_word(current_address));
            cpu.set_reg(sp, current_address + 0x40);
            return;
        }

        for (int i = 0; i < 8; i++) {
            if (register_list[i]) {
                cpu.set_reg__thumb(i, cpu.read_word(current_address & ~3));

                current_address += 4;
            }
        }

        static if (lr_included) {
            Word value = cpu.read_word(current_address & ~3);
            static if (v5TE!T) cpu.set_flag(Flag.T, value[0]);
            cpu.set_reg(pc, value);

            current_address += 4;
        }

        cpu.set_reg(sp, current_address);
    }

    static void create_push(bool lr_included)(T cpu, Half opcode) {
        auto register_list = opcode[0..7];

        Word current_address = cpu.get_reg(sp);

        if (register_list == 0 && !lr_included) {
            cpu.write_word(current_address, cpu.get_reg(pc) + 2);
            if (v4T!T) cpu.set_reg(sp, current_address + 0x40);
            return;
        }

        static if (lr_included) {
            current_address -= 4;
            cpu.write_word(current_address & ~3, cpu.get_reg(lr));
        }

        for (int i = 7; i >= 0; i--) {
            if (register_list[i]) {
                current_address -= 4;
                cpu.write_word(current_address & ~3, cpu.get_reg__thumb(i));
            }
        }

        cpu.set_reg(sp, current_address);
    }

    static void create_store_half(T cpu, Half opcode) {
        Reg rd      = opcode[0..2];
        Reg rn      = opcode[3..5];
        Word offset = opcode[6..10] * 2;

        cpu.strh!(T, true)(rd, cpu.get_reg__thumb(rn) + offset);
    }

    static void create_swi(T cpu, Half opcode) {
        cpu.swi();
    }

    static void create_undefined_instruction(T cpu, Half opcode) {      
        error_unimplemented("Tried to execute undefined THUMB instruction: %04x", opcode);
    }

    static JumptableEntry[256] create_jumptable() {
        JumptableEntry[256] jumptable;

        static foreach (entry; 0 .. 256) {{
            enum Half static_opcode = cast(Half) entry;

            if ((entry & 0b1111_1111) == 0b1101_1111) {
                jumptable[entry] = &create_swi;
            } else

            if ((entry & 0b1111_0000) == 0b1101_0000) {
                enum cond = static_opcode[0..3];
                jumptable[entry] = &create_conditional_branch!cond;
            } else

            if (v5TE!T && (entry & 0b1111_1000) == 0b1110_1000) {
                jumptable[entry] = &create_branch_exchange_with_link;
            } else

            if ((entry & 0b1111_0000) == 0b1111_0000) {
                enum is_first_instruction = !static_opcode[3];
                jumptable[entry] = &create_branch_with_link!is_first_instruction;
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

            if ((entry & 0b1111_1111) == 0b0100_0111) {
                jumptable[entry] = &create_branch_exchange;
            } else

            if ((entry & 0b1111_1000) == 0b0100_1000) {
                enum reg = static_opcode[0..2];
                jumptable[entry] = &create_pc_relative_load!reg;
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