module emu.hw.gpu.slottype;

enum SLOT_SIZE_BG  = 1 << 13;
enum SLOT_SIZE_TEX = 1 << 17;

enum SlotType {
    BG_PAL_A = 0,
    BG_PAL_B = 1,
    OBJ_PAL_A = 2,
    OBJ_PAL_B = 3,
    TEXTURE_PAL = 4,
    TEXTURE = 5
}