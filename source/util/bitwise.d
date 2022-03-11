module util.bitwise;

auto create_mask(size_t start, size_t end) {
    return (1 << (end - start + 1)) - 1;
}