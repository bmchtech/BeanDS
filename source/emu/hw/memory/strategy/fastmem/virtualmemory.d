module emu.hw.memory.strategy.fastmem.virtualmemory;

// import util;

// version (posix) {
//     import std.stdio;
//     import core.sys.posix.unistd;
//     import core.sys.posix.sys.mman;
// }

// extern(C) {
//     int memfd_create(const char *name, uint flags);
// }

// alias MemoryRegionDescriptor = int;

// struct MemoryRegion {
//     MemoryRegionDescriptor descriptor;
//     u32 size;
// };

// abstract class VirtualMemoryManager : Mem {
//     void* base_address;

//     this() {
//         this.base_address = mmap(null, 1 << 28, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
//     }

//     static MemoryRegion create_memory_region(string name, u32 size) {
//         version (posix) {
//             MemoryRegionDescriptor descriptor = memfd_create(cast(char*) name, 0);
//             int result = ftruncate(descriptor, size);

//             return MemoryRegion(
//                 descriptor,
//                 size
//             );
//         } else {
//             error_nds("VirtualMemoryManager not implemented for non-posix systems");
//             return null;
//         }
//     }

//     void map(MemoryRegion* memory_region, u32 address) {
//         version (posix) {
//             void* host_address = this.resolve_address(address);
//             munmap(host_address, memory_region.size);
//             mmap(host_address, memory_region.size, PROT_READ | PROT_WRITE, MAP_FIXED | MAP_SHARED, memory_region.descriptor, 0);
//         } else {
//             error_nds("VirtualMemoryManager not implemented for non-posix systems");
//             return null;
//         }
//     }

//     void map(MemoryRegion* memory_region, u32 address, u32 size) {
//         for (u32 i = 0; i < size; i += memory_region.size) {
//             this.map(memory_region, address + i);
//         }
//     }

//     void* resolve_address(u32 address) {
//         return cast(void*) (base_address + address);
//     }

//     T read(T)(u32 address) {
//         return *(cast(T*) this.resolve_address(address));
//     }

//     void write(T)(u32 address, T value) {
//         *(cast(T*) this.resolve_address(address)) = value;
//     }

//     override {
//         void write_word(Word address, Word value) { write!Word(address, value); }
//         void write_half(Word address, Half value) { write!Half(address, value); }
//         void write_byte(Word address, Byte value) { write!Byte(address, value); }
//         Word read_word(Word address) { return read!Word(address); }
//         Half read_half(Word address) { return read!Half(address); }
//         Byte read_byte(Word address) { return read!Byte(address); }
//     }
// };