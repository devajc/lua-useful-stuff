-- arm specific definitions

local ffi = require "ffi"

local arch = {}

arch.ucontext = function()
ffi.cdef[[
typedef int greg_t, gregset_t[18];
typedef struct sigcontext {
  unsigned long trap_no, error_code, oldmask;
  unsigned long arm_r0, arm_r1, arm_r2, arm_r3;
  unsigned long arm_r4, arm_r5, arm_r6, arm_r7;
  unsigned long arm_r8, arm_r9, arm_r10, arm_fp;
  unsigned long arm_ip, arm_sp, arm_lr, arm_pc;
  unsigned long arm_cpsr, fault_address;
} mcontext_t;
typedef struct __ucontext {
  unsigned long uc_flags;
  struct __ucontext *uc_link;
  stack_t uc_stack;
  mcontext_t uc_mcontext;
  sigset_t uc_sigmask;
  unsigned long long uc_regspace[64];
} ucontext_t;
]]
end

return arch
