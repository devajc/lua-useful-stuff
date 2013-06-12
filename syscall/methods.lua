-- this creates types with methods
-- cannot do this in types as the functions have not been defined yet (as they depend on types)
-- well we could, by passing in the empty table for S, but this is more modular

local function init(S)

local c = S.c
local types = S.types
local t, s, pt = types.t, types.s, types.pt

local bit = require "bit"

local ffi = require "ffi"

local h = require "syscall.helpers"

local function getfd(fd)
  if type(fd) == "number" or ffi.istype(t.int, fd) then return fd end
  return fd:getfd()
end

-- makes code tidier
local function istype(tp, x) if ffi.istype(tp, x) then return x else return false end end

-- even simpler version coerces to type
local function mktype(tp, x) if ffi.istype(tp, x) then return x else return tp(x) end end

-- easier interfaces to some functions that are in common use
local function nonblock(fd)
  local fl, err = S.fcntl(fd, c.F.GETFL)
  if not fl then return nil, err end
  fl, err = S.fcntl(fd, c.F.SETFL, bit.bor(fl, c.O.NONBLOCK))
  if not fl then return nil, err end
  return true
end

local function block(fd)
  local fl, err = S.fcntl(fd, c.F.GETFL)
  if not fl then return nil, err end
  fl, err = S.fcntl(fd, c.F.SETFL, bit.band(fl, bit.bnot(c.O.NONBLOCK)))
  if not fl then return nil, err end
  return true
end

local function tell(fd) return S.lseek(fd, 0, c.SEEK.CUR) end

local function lockf(fd, cmd, len)
  cmd = c.LOCKF[cmd]
  if cmd == c.LOCKF.LOCK then
    return S.fcntl(fd, c.F.SETLKW, {l_type = c.FCNTL_LOCK.WRLCK, l_whence = c.SEEK.CUR, l_start = 0, l_len = len})
  elseif cmd == c.LOCKF.TLOCK then
    return S.fcntl(fd, c.F.SETLK, {l_type = c.FCNTL_LOCK.WRLCK, l_whence = c.SEEK.CUR, l_start = 0, l_len = len})
  elseif cmd == c.LOCKF.ULOCK then
    return S.fcntl(fd, c.F.SETLK, {l_type = c.FCNTL_LOCK.UNLCK, l_whence = c.SEEK.CUR, l_start = 0, l_len = len})
  elseif cmd == c.LOCKF.TEST then
    local ret, err = S.fcntl(fd, c.F.GETLK, {l_type = c.FCNTL_LOCK.WRLCK, l_whence = c.SEEK.CUR, l_start = 0, l_len = len})
    if not ret then return nil, err end
    return ret.l_type == c.FCNTL_LOCK.UNLCK
  end
end

-- methods on an fd
-- note could split, so a socket does not have methods only appropriate for a file; sometimes you do not know what type an fd is
local fdmethods = {'dup', 'read', 'write', 'pread', 'pwrite',
                   'lseek', 'fchdir', 'fsync', 'fdatasync', 'fstat', 'fcntl', 'fchmod',
                   'bind', 'listen', 'connect', 'accept', 'getsockname', 'getpeername',
                   'send', 'sendto', 'recv', 'recvfrom', 'readv', 'writev', 'sendmsg',
                   'recvmsg', 'setsockopt', 'epoll_ctl', 'epoll_wait', 'sendfile', 'getdents',
                   'ftruncate', 'shutdown', 'getsockopt',
                   'inotify_add_watch', 'inotify_rm_watch', 'inotify_read', 'flistxattr',
                   'fsetxattr', 'fgetxattr', 'fremovexattr', 'fxattr', 'splice', 'vmsplice', 'tee',
                   'timerfd_gettime', 'timerfd_settime',
                   'fadvise', 'fallocate', 'posix_fallocate', 'readahead',
                   'sync_file_range', 'fstatfs', 'futimens',
                   'fstatat', 'unlinkat', 'mkdirat', 'mknodat', 'faccessat', 'fchmodat', 'fchown',
                   'fchownat', 'readlinkat', 'setns', 'openat',
                   'preadv', 'pwritev', 'epoll_pwait', 'ioctl'
                   }
local fmeth = {}
for _, v in ipairs(fdmethods) do fmeth[v] = S[v] end

-- defined above
fmeth.block = block
fmeth.nonblock = nonblock
fmeth.tell = tell
fmeth.lockf = lockf

-- allow calling without leading f
fmeth.stat = S.fstat
fmeth.chdir = S.fchdir
fmeth.sync = S.fsync
fmeth.datasync = S.fdatasync
fmeth.chmod = S.fchmod
fmeth.setxattr = S.fsetxattr
fmeth.getxattr = S.gsetxattr
fmeth.truncate = S.ftruncate
fmeth.statfs = S.fstatfs
fmeth.utimens = S.futimens
fmeth.utime = S.futimens
fmeth.seek = S.lseek
fmeth.lock = S.lockf
fmeth.chown = S.fchown

local function nogc(d) return ffi.gc(d, nil) end

fmeth.nogc = nogc

-- sequence number used by netlink messages
fmeth.seq = function(fd)
  fd.sequence = fd.sequence + 1
  return fd.sequence
end

function fmeth.close(fd)
  local fileno = getfd(fd)
  if fileno == -1 then return true end -- already closed
  local ok, err = S.close(fileno)
  fd.filenum = -1 -- make sure cannot accidentally close this fd object again
  return ok, err
end

fmeth.getfd = function(fd) return fd.filenum end

t.fd = ffi.metatype("struct {int filenum; int sequence;}", {
  __index = fmeth,
  __gc = fmeth.close,
  __new = function(tp, i)
    return istype(tp, i) or ffi.new(tp, i)
  end,
})

if S.mq_open then -- TODO better test. TODO support in BSD but will be slightly different as use -lrt not syscalls
local mqmeth = {
  close = fmeth.close,
  nogc = nogc,
  getfd = function(fd) return fd.filenum end,
  getattr = function(mqd, attr)
    attr = attr or t.mq_attr()
    local ok, err = S.mq_getsetattr(mqd, nil, attr)
    if not ok then return nil, err end
    return attr
  end,
  setattr = function(mqd, attr)
    if type(attr) == "number" or type(attr) == "string" then attr = {flags = attr} end -- only flags can be set so allow this
    attr = mktype(t.mq_attr, attr)
    return S.mq_getsetattr(mqd, attr, nil)
  end,
  timedsend = S.mq_timedsend,
  send = function(mqd, msg_ptr, msg_len, msg_prio) return S.mq_timedsend(mqd, msg_ptr, msg_len, msg_prio) end,
  timedreceive = S.mq_timedreceive,
  receive = function(mqd, msg_ptr, msg_len, msg_prio) return S.mq_timedreceive(mqd, msg_ptr, msg_len, msg_prio) end,
}

t.mqd = ffi.metatype("struct {mqd_t filenum;}", {
  __index = mqmeth,
  __gc = mqmeth.close,
  __new = function(tp, i)
    return istype(tp, i) or ffi.new(tp, i)
  end,
})
end

-- override socketpair to provide methods
local mt_socketpair = {
  __index = {
    close = function(s)
      local ok1, err1 = s[1]:close()
      local ok2, err2 = s[2]:close()
      if not ok1 then return nil, err1 end
      if not ok2 then return nil, err2 end
      return true
    end,
    nonblock = function(s)
      local ok, err = S.nonblock(s[1])
      if not ok then return nil, err end
      local ok, err = S.nonblock(s[2])
      if not ok then return nil, err end
      return true
    end,
    block = function(s)
      local ok, err = S.block(s[1])
      if not ok then return nil, err end
      local ok, err = S.block(s[2])
      if not ok then return nil, err end
      return true
    end,
    setblocking = function(s, b)
      local ok, err = S.setblocking(s[1], b)
      if not ok then return nil, err end
      local ok, err = S.setblocking(s[2], b)
      if not ok then return nil, err end
      return true
    end,
  }
}

t.socketpair = function(s1, s2)
  if ffi.istype(t.int2, s1) then s1, s2 = s1[0], s1[1] end
  return setmetatable({t.fd(s1), t.fd(s2)}, mt_socketpair)
end

-- override pipe to provide methods
local mt_pipe = {
  __index = {
    close = function(p)
      local ok1, err1 = p[1]:close()
      local ok2, err2 = p[2]:close()
      if not ok1 then return nil, err1 end
      if not ok2 then return nil, err2 end
      return true
    end,
    read = function(p, ...) return S.read(p[1], ...) end,
    write = function(p, ...) return S.write(p[2], ...) end,
    nonblock = function(p)
      local ok, err = p[1]:nonblock()
      if not ok then return nil, err end
      local ok, err = p[2]:nonblock()
      if not ok then return nil, err end
      return true
    end,
    block = function(p)
      local ok, err = p[1]:block()
      if not ok then return nil, err end
      local ok, err = p[2]:block()
      if not ok then return nil, err end
      return true
    end,
    setblocking = function(p, b)
      local ok, err = p[1]:setblocking(b)
      if not ok then return nil, err end
      local ok, err = p[2]:setblocking(b)
      if not ok then return nil, err end
      return true
    end,
    -- TODO many useful methods still missing
  }
}

t.pipe = function(s1, s2)
  if ffi.istype(t.int2, s1) then s1, s2 = s1[0], s1[1] end
  return setmetatable({t.fd(s1), t.fd(s2)}, mt_pipe)
end

S.stdin = t.fd(c.STD.IN):nogc()
S.stdout = t.fd(c.STD.OUT):nogc()
S.stderr = t.fd(c.STD.ERR):nogc()

-- TODO reinstate this, more like fd is, hence changes to destroy
--[[
t.aio_context = ffi.metatype("struct {aio_context_t ctx;}", {
  __index = {destroy = S.io_destroy, submit = S.io_submit, getevents = S.io_getevents, cancel = S.io_cancel, nogc = nogc},
  __gc = S.io_destroy
})
]]


return S

end

return {init = init}

