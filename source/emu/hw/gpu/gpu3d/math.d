module emu.hw.gpu.gpu3d.math;

import util;

alias Vec2(T) = Vec!(2, T);
alias Vec3(T) = Vec!(3, T);
alias Vec4(T) = Vec!(4, T);

alias Mat4x4(T) = SquareMatrix!(4, T);

alias Coordinate = FixedPoint!(4, 12);
alias Matrix = Mat4x4!Coordinate;
alias Point = Vec4!Coordinate;

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