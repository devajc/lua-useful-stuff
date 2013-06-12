module(...,package.seeall)

local lib = require("lib")
local ffi = require("ffi")
local C = ffi.C
require("memory_h")

--- ### Serve small allocations from hugepage "chunks"

-- List of all allocated huge pages: {pointer, physical, size, used}
-- The last element is used to service new DMA allocations.
chunks = {}

-- Allocate DMA-friendly memory.
-- Return virtual memory pointer, physical address, and actual size.
function dma_alloc (bytes)
   assert(bytes <= huge_page_size)
   bytes = lib.align(bytes, 128)
   if #chunks == 0 or bytes + chunks[#chunks].used > chunks[#chunks].size then
      allocate_next_chunk()
   end
   local chunk = chunks[#chunks]
   local where = chunk.used
   chunk.used = chunk.used + bytes
   return chunk.pointer + where, chunk.physical + where, bytes
end

-- Add a new chunk.
function allocate_next_chunk ()
   local ptr = allocate_huge_page()
   chunks[#chunks + 1] = { pointer = ffi.cast("char*", ptr),
                           physical = virtual_to_physical(ptr),
                           size = huge_page_size,
                           used = 0 }
end

--- ### HugeTLB: Allocate contiguous memory in bulk from Linux

function allocate_huge_page ()
   local attempts = 3
   for i = 1,attempts do
      local page = C.allocate_huge_page(huge_page_size)
      if page ~= nil then  return page  else  reserve_new_page()  end
   end
   error("Failed to allocate a huge page.")
end

function reserve_new_page ()
   set_hugepages(get_hugepages() + 1)
end

function get_hugepages ()
   return lib.readfile("/proc/sys/vm/nr_hugepages", "*n")
end

function set_hugepages (n)
   lib.writefile("/proc/sys/vm/nr_hugepages", tostring(n))
end

function get_huge_page_size ()
   local meminfo = lib.readfile("/proc/meminfo", "*a")
   local _,_,hugesize = meminfo:find("Hugepagesize: +([0-9]+) kB")
   return tonumber(hugesize) * 1024
end

base_page_size = 4096
huge_page_size = get_huge_page_size()

--- ### Physical address translation

-- Convert from virtual address (pointer) to physical address (uint64_t).
function virtual_to_physical (virt_addr)
   virt_addr = ffi.cast("uint64_t", virt_addr)
   local virt_page = tonumber(virt_addr / base_page_size)
   local offset    = tonumber(virt_addr % base_page_size)
   local phys_page = C.phys_page(virt_page)
   if phys_page == 0 then
      error("Failed to resolve physical address of "..tostring(virt_addr))
   end
   return ffi.cast("uint64_t", phys_page * base_page_size + offset)
end

--- ### selftest

function selftest (options)
   print("selftest: memory")
   print("HugeTLB pages (/proc/sys/vm/nr_hugepages): " .. get_hugepages())
   for i = 1, 4 do
      io.write("  Allocating a "..(huge_page_size/1024/1024).."MB HugeTLB: ")
      io.flush()
      local dmaptr, physptr, dmalen = dma_alloc(huge_page_size)
      print("Got "..(dmalen/1024^2).."MB "..
         "at 0x"..tostring(ffi.cast("void*",tonumber(physptr))))
      ffi.cast("uint32_t*", dmaptr)[0] = 0xdeadbeef -- try a write
      assert(dmaptr ~= nil and dmalen == huge_page_size)
   end
   print("HugeTLB pages (/proc/sys/vm/nr_hugepages): " .. get_hugepages())
   print("HugeTLB page allocation OK.")
end

--- ### module init: `mlock()` at load time

--- This module requires a stable physical-virtual mapping so this is
--- enforced automatically at load-time.
assert(C.lock_memory() == 0)

