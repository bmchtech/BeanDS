module emu.hw.memory.slot;

import emu.hw.cpu.armcpu;
import emu.hw.hwtype;
import util;

__gshared Slot slot;
final class Slot {
    // i currently only use nds_slot_access_rights, but i'm keeping the rest
    // of the variables around for clarity + in case i need to use them later.

    HwType nds_slot_access_rights;
    HwType gba_slot_access_rights;

    int gba_slot_sram_access_time_7;
    int gba_slot_rom_first_access_time_7;
    int gba_slot_rom_second_access_time_7;
    int gba_slot_phi_pin_out_7;

    int gba_slot_sram_access_time_9;
    int gba_slot_rom_first_access_time_9;
    int gba_slot_rom_second_access_time_9;
    int gba_slot_phi_pin_out_9;

    bool main_memory_interface_mode_switch;
    HwType main_memory_access_priority;

    this() {

    }

    void reset() {
        // something with nds_slot_access_rights???
    }

    void write_EXMEMCNT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                gba_slot_sram_access_time_9       = data[0..1];
                gba_slot_rom_first_access_time_9  = data[2..3];
                gba_slot_rom_second_access_time_9 = data[4];
                gba_slot_phi_pin_out_9            = data[5..6];
                gba_slot_access_rights            = data[7] ? HwType.NDS7 : HwType.NDS9;
                break;
            
            case 1:
                nds_slot_access_rights            = data[3] ? HwType.NDS7 : HwType.NDS9;
                main_memory_interface_mode_switch = data[6];
                main_memory_access_priority       = data[7] ? HwType.NDS7 : HwType.NDS9;
                break;

        }
    }

    Byte read_EXMEMCNT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0..1] = gba_slot_sram_access_time_9;
                result[2..3] = gba_slot_rom_first_access_time_9;
                result[4]    = gba_slot_rom_second_access_time_9;
                result[5..6] = gba_slot_phi_pin_out_9;
                result[7]    = gba_slot_access_rights == HwType.NDS7 ? 1 : 0;
                break;
            
            case 1:
                result[3]    = nds_slot_access_rights == HwType.NDS7 ? 1 : 0;
                result[6]    = main_memory_interface_mode_switch;
                result[7]    = main_memory_access_priority == HwType.NDS7 ? 1 : 0;
                break;
        }
        
        return result;
    }

    void write_EXMEMSTAT(int target_byte, Byte data) {
        final switch (target_byte) {
            case 0:
                gba_slot_sram_access_time_7       = data[0..1];
                gba_slot_rom_first_access_time_7  = data[2..3];
                gba_slot_rom_second_access_time_7 = data[4];
                gba_slot_phi_pin_out_7            = data[5..6];
                break;

            case 1:
                break;
        }
    }

    Byte read_EXMEMSTAT(int target_byte) {
        Byte result;

        final switch (target_byte) {
            case 0:
                result[0..1] = gba_slot_sram_access_time_7;
                result[2..3] = gba_slot_rom_first_access_time_7;
                result[4]    = gba_slot_rom_second_access_time_7;
                result[5..6] = gba_slot_phi_pin_out_7;
                result[7]    = gba_slot_access_rights == HwType.NDS7 ? 1 : 0;
                break;
            
            case 1:
                result[3]    = nds_slot_access_rights == HwType.NDS7 ? 1 : 0;
                result[6]    = main_memory_interface_mode_switch;
                result[7]    = main_memory_access_priority == HwType.NDS7 ? 1 : 0;
                break;
        }
        
        return result;
    }
}