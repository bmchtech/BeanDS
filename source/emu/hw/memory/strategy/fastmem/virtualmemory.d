module emu.hw.memory.strategy.fastmem.virtualmemory;

import util;

version (Posix) {
    import core.sys.posix.signal;
    import core.sys.posix.sys.mman;
    import core.sys.posix.unistd;
    import std.stdio;
}

extern(C) {
    int memfd_create(const char *name, uint flags);
}

alias MemoryRegionDescriptor = int;

struct MemoryRegion {
    string name;
    MemoryRegionDescriptor descriptor;
    u64 size;
}

struct VirtualMemorySpace {
    string name;
    void* base_address;
    u64 size;
}

// TODO: check the return values of all syscalls
// currently i just hope they return succesfully lol
final class VirtualMemoryManager {
    private VirtualMemorySpace[] memory_spaces;

    // illegal accesses will get routed to this. sure this is inaccurate
    // but it'll work just fine
    private MemoryRegion* illegal_access_page;

    this(size_t size) {
        sigaction_t sa;
        sa.sa_flags = SA_SIGINFO;
        sa.sa_sigaction = &segfault_handler;
        sigaction(SIGSEGV, &sa, null);
        _virtual_memory_manager = this;

        illegal_access_page = create_memory_region("illegal_access_page", 0x1000);
    }

    VirtualMemorySpace* create_memory_space(string name, u64 size) {
        VirtualMemorySpace space = VirtualMemorySpace(
            name,
            mmap(null, size, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0),
            size
        );

        this.memory_spaces ~= space;
        return &this.memory_spaces[$ - 1];
    }

    MemoryRegion* create_memory_region(string name, u64 size) {
        version (Posix) {
            MemoryRegionDescriptor descriptor = memfd_create(cast(char*) name, 0);
            int result = ftruncate(descriptor, size);

            return new MemoryRegion(
                name,
                descriptor,
                size
            );
        } else {
            error_nds("VirtualMemoryManager not implemented for non-posix systems");
            assert(0);
        }
    }

    void map(VirtualMemorySpace* space, MemoryRegion* memory_region, u64 address) {
        version (Posix) {
            void* host_address = this.to_host_address(space, address);
            
            int unmap_error = munmap(host_address, memory_region.size);
            if (unmap_error < 0) {
                perror("unmap");
                error_nds("Failed to unmap memory region");
                assert(0);
            }

            void* map_error = mmap(host_address, memory_region.size, PROT_READ | PROT_WRITE, MAP_FIXED | MAP_SHARED, memory_region.descriptor, 0);
            if (cast(u64) map_error < 0) {
                error_nds("Failed to map memory region");
                assert(0);
            }
        } else {
            error_nds("VirtualMemoryManager not implemented for non-posix systems");
            assert(0);
        }
    }

    void map_with_length(VirtualMemorySpace* space, MemoryRegion* memory_region, u64 address, u64 size) {
        map_with_stride(space, memory_region, address, size, memory_region.size);
    }

    void map_with_stride(VirtualMemorySpace* space, MemoryRegion* memory_region, u64 address, u64 size, u64 stride) {
        for (u64 i = 0; i < size; i += stride) {
            this.map(space, memory_region, address + i);
        }
    }

    void* to_host_address(VirtualMemorySpace* space, u64 address) {
        return cast(void*) (space.base_address + address);
    }

    u64 to_guest_address(VirtualMemorySpace* space, void* address) {
        return cast(u64) (address - space.base_address);
    }

    T read(T)(VirtualMemorySpace* space, u64 address) {
        return *(cast(T*) this.to_host_address(space, address));
    }

    void write(T)(VirtualMemorySpace* space, u64 address, T value) {
        *(cast(T*) this.to_host_address(space, address)) = value;
    }

    bool in_range(VirtualMemorySpace* space, void* address) {
        return address >= space.base_address && address < space.base_address + space.size;
    }
}

__gshared VirtualMemoryManager _virtual_memory_manager;
version (Posix) {
    extern(C) 
    private void segfault_handler(int signum, siginfo_t* info, void* context) {
        for (int i = 0; i < _virtual_memory_manager.memory_spaces.length; i++) {
            VirtualMemorySpace* space = &_virtual_memory_manager.memory_spaces[i];
            if (_virtual_memory_manager.in_range(space, info.si_addr)) {
                if (_virtual_memory_manager.to_guest_address(space, info.si_addr) == 0x0400_0000) error_nds("shit.");

                log_nds("Illegal memory access in space %s at address 0x%08x. Fixing via mmap... (%x)", space.name, _virtual_memory_manager.to_guest_address(space, info.si_addr), info.si_addr);
                _virtual_memory_manager.map(space, _virtual_memory_manager.illegal_access_page, _virtual_memory_manager.to_guest_address(space, cast(void*) (cast(u64) info.si_addr & ~0xFFF)));
                return;
            }
        }

        error_nds("Segfault at address %x.", info.si_addr);

        // errors can be silenced with a config parameter. we need to forcibly stop execution
        _exit(-1);
    }
}