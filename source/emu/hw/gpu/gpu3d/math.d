module emu.hw.gpu.gpu3d.math;

import util;

alias Vec2(T) = Vec!(2, T);

alias Vec3(T) = Vec!(3, T);
alias Vec4(T) = Vec!(4, T);

alias Mat4x4(T) = SquareMatrix!(4, T);

alias Coord_4_12 = FixedPoint!(4, 12);
alias Coord_20_12 = FixedPoint!(20, 12);
alias Coord_14_18 = FixedPoint!(14, 18);

alias Point_4_12 = Vec4!Coord_4_12;
alias Point_14_18 = Vec4!Coord_14_18;
alias Point_20_12 = Vec4!Coord_20_12;

alias Matrix = Mat4x4!Coord_20_12;

struct Vec(int N, T) {
    T[N] data;
    alias data this;
    
    this(T[N] data) {
        this.data = data;
    }
    
    T dot(Vec!(N, T) other) {
        T result = 0;

        for (int i = 0; i < N; i++) {
            result = result + this[i] * other[i];
        }

        return result;
    }
}

struct SquareMatrix(int N,T) {
    T[N][N] data;
    alias data this;
    
    this(T[N][N] data) {
        this.data = data;
    }
    
    SquareMatrix!(N, T) opBinary(string op : "*")(SquareMatrix!(N, T) other) {
        SquareMatrix!(N, T) result;

        for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            result[i][j] = T(0);
            for (int k = 0; k < N; k++) {
                result[i][j] = result[i][j] + this[i][k] * other[k][j];
            }
        }
        }
        
        return result;
    }
    
    Vec!(N, T) opBinary(string op : "*")(Vec!(N, T) other) {
        Vec!(N, T) result;
        
        for (int i = 0; i < N; i++) {
            result[i] = T(0);

            for (int j = 0; j < N; j++) {
                result[i] = result[i] + this[i][j] * other[j];
            }
        }
        
        return result;
    }

    static SquareMatrix!(N, T) identity() {
        return SquareMatrix!(N, T)([
            [T(1), T(0), T(0), T(0)],
            [T(0), T(1), T(0), T(0)],
            [T(0), T(0), T(1), T(0)],
            [T(0), T(0), T(0), T(1)]
        ]);
    }
}

float fixed_point_to_float(int fractional_part)(int fixed_point) {
    return (cast(float) (fixed_point >> fractional_part)) + (cast(float) (fixed_point & (create_mask(0, fractional_part - 1))) / (cast(float) (1 << fractional_part)));
}

float signed_fixed_point_to_float(int fractional_part)(int fixed_point) {
    int integer_part = fixed_point >> fractional_part;
    float fractional_part = (cast(float) (fixed_point & (create_mask(0, fractional_part - 1))) / (cast(float) (1 << fractional_part)));
    return integer_part + fractional_part;
}