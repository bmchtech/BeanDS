module emu.hw.gpu.gpu3d.math;

alias Vec4 = Vec!4;
alias Mat4x4 = SquareMatrix!4;

struct Vec(int N) {
    float[N] data;
    alias data this;
    
    this(float[N] data) {
        this.data = data;
    }
    
    float dot(Vec!N other) {
        float result = 0;

        for (int i = 0; i < N; i++) {
            result += this[i] * other[i];
        }

        return result;
    }
}

struct SquareMatrix(int N) {
    float[N][N] data;
    alias data this;
    
    this(float[N][N] data) {
        this.data = data;
    }
    
    SquareMatrix!N opBinary(string op : "*")(SquareMatrix!N other) {
        SquareMatrix!N result;

        for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            result[i][j] = 0;
            for (int k = 0; k < N; k++) {
                result[i][j] += this[i][k] * other[k][j];
            }
        }
        }
        
        return result;
    }
    
    Vec!N opBinary(string op : "*")(Vec!N other) {
        Vec!N result;
        
        for (int i = 0; i < N; i++) {
            result[i] = 0;

            for (int j = 0; j < N; j++) {
                result[i] += this[i][j] * other[j];
            }
        }
        
        return result;
    }
}