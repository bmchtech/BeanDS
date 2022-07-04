module emu.hw.math.division;

import util;

__gshared DivController math_div;
public class DivController {
    int mode;

    Word numerator_lo;
    Word numerator_hi;
    Word denominator_lo;
    Word denominator_hi;

    bool division_by_zero;
    u64 div_result;
    u64 divrem_result;

    Byte read_DIVCNT(int target_byte) {
        if (target_byte == 0) return Byte(mode);
        if (target_byte == 1) return Byte(division_by_zero << 6);
        return Byte(0);
    }

    void write_DIVCNT(int target_byte, Byte data) {
        if (target_byte == 0) {
            mode = data[0..1]; 
            if (mode == 3) error_division("DIVCNT set to mode 3");
        }
    }

    Byte read_DIV_NUMER(int target_byte) {
        bool hi    = target_byte.bit(2);
        int offset = target_byte.bits(0, 1);
        
        if (hi) return numerator_hi.get_byte(offset);
        else    return numerator_lo.get_byte(offset);
    }

    void write_DIV_NUMER(int target_byte, Byte data) {
        bool hi = target_byte.bit(2);
        int offset = target_byte.bits(0, 1);
        
        if (hi) numerator_hi.set_byte(offset, data);
        else    numerator_lo.set_byte(offset, data);
    }

    Byte read_DIV_DENOM(int target_byte) {
        bool hi = target_byte.bit(2);
        int offset = target_byte.bits(0, 1);
        
        if (hi) return denominator_hi.get_byte(offset);
        else    return denominator_lo.get_byte(offset);
    }

    void write_DIV_DENOM(int target_byte, Byte data) {
        bool hi = target_byte.bit(2);
        int offset = target_byte.bits(0, 1);
        
        if (hi) denominator_hi.set_byte(offset, data);
        else    denominator_lo.set_byte(offset, data);
    }

    Byte read_DIV_RESULT(int target_byte) {
        calculate_result();
        return Byte((div_result >> (target_byte * 8)) & 0xFF);
    }

    Byte read_DIVREM_RESULT(int target_byte) {
        calculate_result();
        return Byte((divrem_result >> (target_byte * 8)) & 0xFF);
    }

    void calculate_result() {
        s64 numerator = 
            mode == 0 ? 
            sext_64(numerator_lo, 32) : 
            cast(s64) numerator_hi << 32 | cast(s64) numerator_lo;

        s64 denominator = 
            mode != 2 ? 
            sext_64(denominator_lo, 32) : 
            cast(s64) denominator_hi << 32 | cast(s64) denominator_lo;
        
        s64 max =
            mode == 0 ?
            0x8000_0000 :
            0x8000_0000_0000_0000;
        
        bool numerator_is_max =
            mode == 0 ?
            numerator_lo == max :
            numerator    == max;

        bool overflow_occurred = false;
    
        if (denominator == 0) {
            division_by_zero = denominator_hi == 0;
            div_result       = numerator < 0 ? 1 : -1;
            divrem_result    = numerator;

            overflow_occurred = true;
        } else if (numerator_is_max && denominator == -1) {
            division_by_zero = false;
            div_result       = max;
            divrem_result    = numerator % denominator;

            overflow_occurred = true;
        } else {
            division_by_zero = false;
            div_result       = numerator / denominator;
            divrem_result    = numerator % denominator;
        }

        if (mode == 0) {
            div_result = sext_64(div_result & 0xFFFF_FFFF, 32);
        }

        if (denominator != 0 && mode != 2) {
            divrem_result = sext_64(divrem_result & 0xFFFF_FFFF, 32);
        }

        if (mode == 0 && overflow_occurred) div_result ^= 0xFFFF_FFFF_0000_0000;
    }
}