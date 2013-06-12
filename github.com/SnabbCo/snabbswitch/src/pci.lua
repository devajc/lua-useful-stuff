module(...,package.seeall)

local ffi = require("ffi")
local C = ffi.C
local lib = require("lib")

require("clib_h")
require("pci_h")

--- ### Hardware device information

devices = {}

--- Array of all supported hardware devices.
---
--- Each entry is a "device info" table with these attributes:
---
--- * `pciaddress` e.g. `"0000:83:00.1"`
--- * `vendor` id hex string e.g. `"0x8086"` for Intel.
--- * `device` id hex string e.g. `"0x10fb"` for 82599 chip.
--- * `interface` name of Linux interface using this device e.g. `"eth0"`.
--- * `status` string Linux operational status, or `nil` if not known.
--- * `driver` Lua module that supports this hardware e.g. `"intel10g"`.
--- * `usable` device was suitable to use when scanned? `yes` or `no`

--- Initialize (or re-initialize) the `devices` table.
function scan_devices ()
   for _,device in ipairs(lib.files_in_directory("/sys/bus/pci/devices")) do
      local info = device_info(device)
      if info.driver then table.insert(devices, info) end
   end
end

function device_info (pciaddress)
   local info = {}
   local p = path(pciaddress)
   info.pciaddress = pciaddress
   info.vendor = lib.firstline(p.."/vendor")
   info.device = lib.firstline(p.."/device")
   info.interface = lib.firstfile(p.."/net")
   info.driver = which_driver(info.vendor, info.device)
   if info.interface then
      info.status = lib.firstline(p.."/net/"..info.interface.."/operstate")
   end
   info.usable = lib.yesno(is_usable(info))
   return info
end

--- Return the path to the sysfs directory for `pcidev`.
function path(pcidev) return "/sys/bus/pci/devices/"..pcidev end

-- Return the name of the Lua module that implements support for this device.
function which_driver (vendor, device)
   if vendor == '0x8086' then
      if device == '0x10fb' then return 'intel10g' end -- Intel 82599
      if device == '0x10d3' then return 'intel' end    -- Intel 82574L
      if device == '0x105e' then return 'intel' end    -- Intel 82571
   end
end

--- ### Device manipulation.

--- Return true if `device` is safely available for use, or false if
--- the operating systems to be using it.
function is_usable (info)
   return info.driver and (info.interface == nil or info.status == 'down')
end

--- Force Linux to release the device with `pciaddress`.
--- The corresponding network interface (e.g. `eth0`) will disappear.
function unbind_device_from_linux (pciaddress)
   lib.writefile(path(pciaddress).."/driver/unbind", pciaddress)
end

--- Return a pointer for MMIO access to `device` resource `n`.
--- Device configuration registers can be accessed this way.
function map_pci_memory (device, n)
   local filepath = path(device).."/resource"..n
   local addr = C.map_pci_resource(filepath)
   assert( addr ~= 0 )
   return addr
end

--- Enable or disable PCI bus mastering. DMA only works when bus
--- mastering is enabled.
function set_bus_master (device, enable)
   local fd = C.open_pcie_config(path(device).."/config")
   local value = ffi.new("uint16_t[1]")
   assert(C.pread(fd, value, 2, 0x4) == 2)
   if enable then
      value[0] = bit.bor(value[0], lib.bits({Master=2}))
   else
      value[0] = bit.band(value[0], bit.bnot(lib.bits({Master=2})))
   end
   assert(C.pwrite(fd, value, 2, 0x4) == 2)
end

--- ### Open a device
---
--- Load a device driver for a devie. A fresh copy of the device
--- driver's Lua module is loaded for each device and the module is
--- told at load-time the PCI address of the device it is controlling.
--- This makes the driver source code short because it can assume that
--- it's always talking to the same device.
---
--- This is achieved with our own require()-like function that loads a
--- fresh copy and passes the PCI address as an argument.

open_devices = {}

-- Load a new instance of the 'driver' module for 'pciaddress'.
-- On success this creates the Lua module 'driver@pciaddress'.
--
-- Example: open_device("intel10g", "0000:83:00.1") creates module
-- "intel10g@0000:83:00.1" which controls that specific device.
function open_device(pciaddress, driver)
   local instance = driver.."@"..pciaddress
   find_loader(driver)(instance, pciaddress)
   open_devices[pciaddress] = package.loaded[instance]
   return package.loaded[instance]
end

-- (This could be a Lua builtin.)
-- Return loader function for `module`.
-- Calling the loader function will run the module's code.
function find_loader (mod)
   for i = 1, #package.loaders do
      status, loader = pcall(package.loaders[i], mod)
      if type(loader) == 'function' then return loader end
   end
end

--- ### Selftest
---
--- PCI selftest scans for available devices and performs our driver's
--- self-test on each of them.

function selftest ()
   print("selftest: pci")
   print_device_summary()
   open_usable_devices({selftest=true})
end

function print_device_summary ()
   local attrs = {"pciaddress", "vendor", "device", "interface", "status",
                  "driver", "usable"}
   local fmt = "%-13s %-7s %-7s %-10s %-9s %-11s %s"
   print(fmt:format(unpack(attrs)))
   for _,info in ipairs(devices) do
      local values = {}
      for _,attr in ipairs(attrs) do
         table.insert(values, info[attr] or "-")
      end
      print(fmt:format(unpack(values)))
   end
end

function open_usable_devices (options)
   local drivers = {}
   for _,device in ipairs(devices) do
      if device.usable == 'yes' then
         if device.interface ~= nil then
            print("Unbinding device from linux: "..device.pciaddress)
            unbind_device_from_linux(device.pciaddress)
         end
         print("Opening device "..device.pciaddress)
         local driver = open_device(device.pciaddress, device.driver)
         driver.open_for_loopback_test()
         table.insert(drivers, driver)
      end
   end
   local port = require("port")
   local options = {devices=drivers, secs=10,
                    program=port.Port.loopback_test}
   port.selftest(options)
end

function module_init () scan_devices () end

module_init()

