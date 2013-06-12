-- these are types which are currently the same for all ports
-- in a module so rump does not import twice

local cdef = require "ffi".cdef

cdef[[
// 16 bit
typedef uint16_t in_port_t;

// 32 bit
typedef uint32_t uid_t;
typedef uint32_t gid_t;
typedef uint32_t id_t;
typedef int32_t pid_t;

typedef unsigned int socklen_t;

// 64 bit
typedef uint64_t off_t;

// typedefs which are word length
typedef unsigned long nfds_t;

// defined as long even though eg NetBSD defines as int on 32 bit, its the same.
typedef long ssize_t;
typedef unsigned long size_t;

struct iovec {
  void *iov_base;
  size_t iov_len;
};

struct in_addr {
  uint32_t       s_addr;
};
struct in6_addr {
  unsigned char  s6_addr[16];
};
]]

