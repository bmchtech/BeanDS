module emu.debugger.ift.logged_mem;

import emu.all;
import util;

enum MemoryPage {
    BIOS_ARM7          = 0x0,
    BIOS_ARM9          = 0x1,
    MAIN_MEMORY        = 0x2,
    WRAM_SHARED_BANK_1 = 0x3,
    WRAM_SHARED_BANK_2 = 0x4,
    WRAM_ARM7_ONLY     = 0x5,
    MMIO7              = 0x6,
    MMIO9              = 0x7,
    PRAM               = 0x8,
    VRAM_BANK_A        = 0x9,
    VRAM_BANK_B        = 0xA,
    VRAM_BANK_C        = 0xB,
    VRAM_BANK_D        = 0xC,
    VRAM_BANK_E        = 0xD,
    VRAM_BANK_F        = 0xE,
    VRAM_BANK_G        = 0xF,
    VRAM_BANK_H        = 0x10,
    VRAM_BANK_I        = 0x11,
    OAM                = 0x12,
    ITCM               = 0x13,
    DTCM               = 0x14,

    INVALID            = 0x1F
}

struct MemoryPageMirrorPair {
    MemoryPage memory_page;
    Word mirror;
}

MemoryPageMirrorPair get_page_and_mirror(HwType hw_type, Word address) {
    final switch (hw_type) {
        case HwType.NDS7: return get_page_nds7(address);
        case HwType.NDS9: return get_page_nds9(address);
    }
}

MemoryPageMirrorPair get_page_nds7(Word address) {
    auto region = get_region(address);

    if (address[28..31]) return MemoryPageMirrorPair(MemoryPage.INVALID, address);

    switch (region) {
        case 0x0: .. case 0x1: return MemoryPageMirrorPair(MemoryPage.BIOS_ARM7, address % BIOS7_SIZE);
        case 0x2:              return MemoryPageMirrorPair(MemoryPage.MAIN_MEMORY, address % MAIN_MEMORY_SIZE);
        case 0x3:              return get_page_nds7_wram(address);
        case 0x4:              return MemoryPageMirrorPair(MemoryPage.MMIO7, address);
        case 0x6:              return get_page_nds7_vram(address);
    
        default: return MemoryPageMirrorPair(MemoryPage.INVALID, address);
    }
}

MemoryPageMirrorPair get_page_nds7_wram(Word address) {
    // if (address < 0x0380_0000 && wram.arm7_wram_enabled) {
    //     bool bank = address[14];
    //     return MemoryPageMirrorPair(
    //         bank ? MemoryPage.WRAM_SHARED_BANK_1 : MemoryPage.WRAM_SHARED_BANK_2,
    //         address % MAIN_MEMORY_SIZE
    //     );
    // } else {
    //     return MemoryPageMirrorPair(
    //         MemoryPage.WRAM_ARM7_ONLY,
    //         Word(MemoryPage.WRAM_ARM7_ONLY % WRAM.ARM7_ONLY_WRAM_SIZE)
    //     );
    // }
    // TODO: this whole class is going to need restructuring.
    return MemoryPageMirrorPair(MemoryPage.BIOS_ARM7, Word(0));
}

MemoryPageMirrorPair get_page_nds7_vram(Word address) {
    if (vram.vram_c_in_ram && vram.vram_c.in_range(address)) return MemoryPageMirrorPair(MemoryPage.VRAM_BANK_C, address % VRAM_C_SIZE);
    if (vram.vram_d_in_ram && vram.vram_d.in_range(address)) return MemoryPageMirrorPair(MemoryPage.VRAM_BANK_D, address % VRAM_D_SIZE);

    return MemoryPageMirrorPair(MemoryPage.INVALID, address);
}

MemoryPageMirrorPair get_page_nds9(Word address) {
    auto region = get_region(address);

    if (address[28..31]) return MemoryPageMirrorPair(MemoryPage.INVALID, address);

    if (tcm.can_read_itcm(address)) { return MemoryPageMirrorPair(MemoryPage.ITCM, address % tcm.itcm_virtual_size); }
    if (tcm.can_read_dtcm(address)) { return MemoryPageMirrorPair(MemoryPage.DTCM, address % tcm.dtcm_virtual_size); }

    switch (region) {
        case 0x0: .. case 0x1: return MemoryPageMirrorPair(MemoryPage.BIOS_ARM9, address % BIOS7_SIZE);
        case 0x2:              return MemoryPageMirrorPair(MemoryPage.MAIN_MEMORY, address % MAIN_MEMORY_SIZE);
        case 0x3:              return get_page_nds9_wram(address);
        case 0x4:              return MemoryPageMirrorPair(MemoryPage.MMIO9, address);
        case 0x5:              return MemoryPageMirrorPair(MemoryPage.PRAM, address % PRAM_SIZE);
        case 0x6:              return get_page_nds9_vram(address);
        case 0x7:              return MemoryPageMirrorPair(MemoryPage.OAM, address % OAM_SIZE);
    
        default: return MemoryPageMirrorPair(MemoryPage.INVALID, address);
    }
}

MemoryPageMirrorPair get_page_nds9_wram(Word address) {
    bool bank = address[14];
    return MemoryPageMirrorPair(
        bank ? MemoryPage.WRAM_SHARED_BANK_1 : MemoryPage.WRAM_SHARED_BANK_2,
        address % WRAM_SIZE
    );
}

MemoryPageMirrorPair get_page_nds9_vram(Word address) {
    bool found_block = false;

    VRAMBlock target_block;
    for (int i = 0; i < 10; i++) {
        if (i == 2 && vram.vram_c_in_ram) continue;
        if (i == 3 && vram.vram_d_in_ram) continue;

        VRAMBlock block = vram.blocks[i];

        if (block.slot_mapped) continue;

        if (block.in_range(address)) {
            target_block = block;
            found_block = true;
        }
    }

    if (!found_block) return MemoryPageMirrorPair(MemoryPage.INVALID, address);
    return get_page_from_vram_block(target_block, address);
}

MemoryPageMirrorPair get_page_from_vram_block(VRAMBlock vram_block, Word address) {
    MemoryPage page;

    // stupid
    if (vram_block == vram.vram_a) page = MemoryPage.VRAM_BANK_A;
    if (vram_block == vram.vram_b) page = MemoryPage.VRAM_BANK_B;
    if (vram_block == vram.vram_c) page = MemoryPage.VRAM_BANK_C;
    if (vram_block == vram.vram_d) page = MemoryPage.VRAM_BANK_D;
    if (vram_block == vram.vram_e) page = MemoryPage.VRAM_BANK_E;
    if (vram_block == vram.vram_f) page = MemoryPage.VRAM_BANK_F;
    if (vram_block == vram.vram_g) page = MemoryPage.VRAM_BANK_G;
    if (vram_block == vram.vram_h) page = MemoryPage.VRAM_BANK_H;
    if (vram_block == vram.vram_i) page = MemoryPage.VRAM_BANK_I;

    return MemoryPageMirrorPair(page, Word(address % vram_block.size));
}

ulong create_paddr(HwType hw_type, Word address) {
    auto page_and_mirror = get_page_and_mirror(hw_type, address);

    ulong result = 0;
    result |= (cast(ulong) page_and_mirror.memory_page) << 0;
    result |= (cast(ulong) page_and_mirror.mirror)      << 32;
    result |= (cast(ulong) hwtype_to_ulong(hw_type))    << 37;

    return result;
}