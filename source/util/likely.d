module util.likely;

pragma(inline, true) bool likely(bool value) {
    version (LDC) {
        import ldc.intrinsics;
        return llvm_expect!bool(value, true);
    } else {
        return value;
    }
}

pragma(inline, true) bool unlikely(bool value) {
    version (LDC) {
        import ldc.intrinsics;
        return llvm_expect!bool(value, false);
    } else {
        return value;
    }
}