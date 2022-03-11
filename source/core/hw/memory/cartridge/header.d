module core.hw.memory.cartridge.header;

import util;

struct CartridgeHeader {
    align(1):

    Byte[12]   game_title;
    Byte[4]    game_code;
    Byte[2]    maker_code;
    Byte       unit_code;
    Byte       encryption_seed_select;
    Byte       device_capacity;
    Byte[8]    reserved_1;
    Byte       nds_region;
    Byte       rom_version;
    Byte       autostart; 

    Word       arm9_rom_offset;
    Word       arm9_entry_address;
    Word       arm9_ram_address;
    Word       arm9_size;
    Word       arm7_rom_offset;
    Word       arm7_entry_address;
    Word       arm7_ram_address;
    Word       arm7_size;

    Word       fnt_offset;
    Word       fnt_size;
    Word       fat_offset;
    Word       fat_size;

    Word       arm9_overlay_offset;
    Word       arm9_overlay_size;
    Word       arm7_overlay_offset;
    Word       arm7_overlay_size;

    Word       port_setting_normal_commands;
    Word       port_setting_key1_commands;
    Word       icon_offset;
    Half       secure_area_checksum;
    Half       secure_area_delay;
    Word       arm9_auto_load_list_hook_ram_address;
    Word       arm7_auto_load_list_hook_ram_address;
    Byte[8]    secure_area_disable;
    Word       total_used_rom_size;
    Word       rom_header_size;
    Word       unknown;
    Word       reserved_2;
    Half       nand_end_of_rom_area;
    Half       nand_start_of_rw_area;
    Byte[40]   reserved_3;
    Byte[156]  nintendo_logo;
    Half       nintendo_logo_checksum;
    Half       header_checksum;
    
    Word       debug_rom_offset;
    Word       debug_size;
    Word       debug_ram_address;
    Byte[3732] reserved_4;
}

CartridgeHeader* get_cartridge_header(Byte[] rom) {
    return cast(CartridgeHeader*) cast(void*) rom;
}