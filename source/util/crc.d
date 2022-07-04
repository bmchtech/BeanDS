module util.crc;

import emu;
import util;

// short crc16(byte* data, int length) {
//     short result = cast(short) 0xFFFF;

//     for (int i = 0; i < length; i++) {
//         result ^= data[i] << 8;
//         for (int j = 0; j < 8; j++) {
//             if ((result & 0x8000) > 0) {
//                 result = cast(short) ((result << 1) ^ 0x1021);
//             } else {
//                 result = cast(short) (result << 1);
//             }
//         }
//     }

//     return result;
// }

int[16] crc_table = [
    0x0000,
    0xCC01,
    0xD801,
    0x1400,
    0xF001,
    0x3C00,
    0x2800,
    0xe401,
    0xa001,
    0x6c00,
    0x7800,
    0xb401,
    0x5000,
    0x9c01,
    0x8801,
    0x4400
];
short crc16(uint param_1, ushort *start, uint len) {
    uint uVar1;
    uint in_r3;
    ushort *end;
  
    end = cast(ushort*) (cast(ulong) start + (len & 0xfffffffe));
    uVar1 = 0;
    while (start < end) {
        if (uVar1 == 0) {
            in_r3 = cast(uint)*start;
        }
        
        param_1 = (cast(uint)crc_table[(param_1 & 0xf)] ^ (((param_1 & 0xFFFF) << 0xc) >> 0x10)) ^
                (cast(uint)crc_table[((((cast(int)in_r3) >> (uVar1 & 0xff)) & 0xfU))]);
        uVar1 = uVar1 + 4;
        if (0xf < uVar1) {
            uVar1 = 0;
            start = start + 1;
        }
    }
    
    return cast(short) param_1;
}