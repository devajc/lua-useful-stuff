-- Linux specific tests

-- TODO stop using globals for tests

local S = require "syscall"
local abi = S.abi
local types = S.types
local c = S.c
local features = require "syscall.features"

local bit = require "bit"
local ffi = require "ffi"

local t, pt, s = types.t, types.pt, types.s

local nl = require "syscall.linux.nl"
local util = require "syscall.linux.util"

local helpers = require "syscall.helpers"

local oldassert = assert
local function assert(cond, s)
  collectgarbage("collect") -- force gc, to test for bugs
  return oldassert(cond, tostring(s)) -- annoyingly, assert does not call tostring!
end

local function fork_assert(cond, str) -- if we have forked we need to fail in main thread not fork
  if not cond then
    print(tostring(str))
    print(debug.traceback())
    S.exit("failure")
  end
  return cond, str
end

local function assert_equal(...)
  collectgarbage("collect") -- force gc, to test for bugs
  return assert_equals(...)
end

local teststring = "this is a test string"
local size = 512
local buf = t.buffer(size)
local tmpfile = "XXXXYYYYZZZ4521" .. S.getpid()
local tmpfile2 = "./666666DDDDDFFFF" .. S.getpid()
local tmpfile3 = "MMMMMTTTTGGG" .. S.getpid()
local longfile = "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" .. S.getpid()
local efile = "./tmpexXXYYY" .. S.getpid() .. ".sh"
local largeval = math.pow(2, 33) -- larger than 2^32 for testing
local mqname = "ljsyscallXXYYZZ" .. S.getpid()

local clean = function()
  S.rmdir(tmpfile)
  S.unlink(tmpfile)
  S.unlink(tmpfile2)
  S.unlink(tmpfile3)
  S.unlink(longfile)
  S.unlink(efile)
end

test_file_operations_linux = {
  test_openat = function()
    local dfd = S.open(".")
    local fd = assert(dfd:openat(tmpfile, "rdwr,creat", "rwxu"))
    assert(dfd:unlinkat(tmpfile))
    assert(fd:close())
    assert(dfd:close())
  end,
  test_faccessat = function()
    local fd = S.open("/dev")
    assert(fd:faccessat("null", "r"), "expect access to say can read /dev/null")
    assert(fd:faccessat("null", c.OK.R), "expect access to say can read /dev/null")
    assert(fd:faccessat("null", "w"), "expect access to say can write /dev/null")
    assert(not fd:faccessat("/dev/null", "x"), "expect access to say cannot execute /dev/null")
    assert(fd:close())
  end,
  test_linkat = function()
    local dirfd = assert(S.open("."))
    local fd = assert(S.creat(tmpfile, "RWXU"))
    assert(S.linkat(dirfd, tmpfile, dirfd, tmpfile2, "symlink_follow"))
    assert(S.unlink(tmpfile2))
    assert(S.unlink(tmpfile))
    assert(fd:close())
    assert(dirfd:close())
  end,
  test_symlinkat = function()
    local dirfd = assert(S.open("."))
    local fd = assert(S.creat(tmpfile, "RWXU"))
    assert(S.symlinkat(tmpfile, dirfd, tmpfile2))
    local s = assert(S.readlinkat(dirfd, tmpfile2))
    assert_equal(s, tmpfile, "should be able to read symlink")
    assert(S.unlink(tmpfile2))
    assert(S.unlink(tmpfile))
    assert(fd:close())
    assert(dirfd:close())
  end,
  test_fchmodat = function()
    local dirfd = assert(S.open("."))
    local fd = assert(S.creat(tmpfile, "RWXU"))
    assert(dirfd:fchmodat(tmpfile, "RUSR, WUSR"))
    assert(S.access(tmpfile, "rw"))
    assert(S.unlink(tmpfile))
    assert(fd:close())
    assert(dirfd:close())
  end,
  test_fchownat_root = function()
    local dirfd = assert(S.open("."))
    local fd = assert(S.creat(tmpfile, "RWXU"))
    assert(dirfd:fchownat(tmpfile, 66, 55, "symlink_nofollow"))
    local stat = S.stat(tmpfile)
    assert_equal(stat.uid, 66, "expect uid changed")
    assert_equal(stat.gid, 55, "expect gid changed")
    assert(S.unlink(tmpfile))
    assert(fd:close())
    assert(dirfd:close())
  end,
  test_sync_file_range = function()
    local fd = assert(S.creat(tmpfile, "RWXU"))
    assert(fd:sync_file_range(0, 4096, "wait_before, write, wait_after"))
    assert(S.unlink(tmpfile))
    assert(fd:close())
  end,
  test_mkdirat_unlinkat = function()
    local fd = assert(S.open("."))
    assert(fd:mkdirat(tmpfile, "RWXU"))
    assert(fd:unlinkat(tmpfile, "removedir"))
    assert(not fd:fstatat(tmpfile), "expect dir gone")
  end,
  test_renameat = function()
    local fd = assert(S.open("."))
    assert(util.writefile(tmpfile, teststring, "RWXU"))
    assert(S.renameat(fd, tmpfile, fd, tmpfile2))
    assert(not S.stat(tmpfile))
    assert(S.stat(tmpfile2))
    assert(fd:close())
    assert(S.unlink(tmpfile2))
  end,
  test_fstatat = function()
    local fd = assert(S.open("."))
    assert(util.writefile(tmpfile, teststring, "RWXU"))
    local stat = assert(fd:fstatat(tmpfile))
    assert(stat.size == #teststring, "expect length to br what was written")
    assert(fd:close())
    assert(S.unlink(tmpfile))
  end,
  test_fstatat_fdcwd = function()
    assert(util.writefile(tmpfile, teststring, "RWXU"))
    local stat = assert(S.fstatat("fdcwd", tmpfile, nil, "no_automount, symlink_nofollow"))
    assert(stat.size == #teststring, "expect length to br what was written")
    assert(S.unlink(tmpfile))
  end,
  test_fadvise_etc = function() -- could split
    local fd = assert(S.open(tmpfile, "creat, rdwr", "RWXU"))
    assert(S.unlink(tmpfile))
    assert(S.fadvise(fd, "random"))
    local ok, err = S.fallocate(fd, "keep_size", 1024, 4096)
    assert(ok or err.OPNOTSUPP or err.NOSYS, "expect fallocate to succeed if supported")
    ok, err = S.posix_fallocate(fd, 0, 8192)
    assert(ok or err.OPNOTSUPP or err.NOSYS, "expect posix_fallocate to succeed if supported")
    assert(S.readahead(fd, 0, 4096))
    -- disabled as will often give ENOSPC! TODO better test
    --local ok, err = S.fallocate(fd, "keep_size", largeval, largeval + 1) -- test 64 bit ops 8589934592, 8589934593
    --assert(ok or err.OPNOTSUPP or err.NOSYS, "expect fallocate to succeed if supported, got " .. tostring(err))
    assert(fd:close())
  end,
  test_mknodat_fifo = function()
    local fd = assert(S.open("."))
    assert(fd:mknodat(tmpfile, "fifo,rwxu"))
    local stat = assert(S.stat(tmpfile))
    assert(stat.isfifo, "expect to be a fifo")
    assert(fd:close())
    assert(S.unlink(tmpfile))
  end,
  test_mkfifoat = function()
    local fd = assert(S.open("."))
    assert(S.mkfifoat(fd, tmpfile, "rwxu"))
    local stat = assert(S.stat(tmpfile))
    assert(stat.isfifo, "expect to be a fifo")
    assert(fd:close())
    assert(S.unlink(tmpfile))
  end,
}

test_directory_operations = {
-- tests getdents from higher level interface TODO move to util test, test directly too? make portable
  test_getdents_dirfile = function()
    local d = assert(util.dirfile("/dev"))
    assert(d.zero, "expect to find /dev/zero")
    assert(d["."], "expect to find .")
    assert(d[".."], "expect to find ..")
    assert(d.zero.chr, "/dev/zero is a character device")
    assert(d["."].dir, ". is a directory")
    assert(not d["."].chr, ". is not a character device")
    assert(not d["."].sock, ". is not a socket")
    assert(not d["."].lnk, ". is not a synlink")
    assert(d[".."].dir, ".. is a directory")
  end,
  test_getdents_error = function()
    local fd = assert(S.open("/dev/zero", "RDONLY"))
    local d, err = S.getdents(fd)
    assert(err.notdir, "/dev/zero should give a not directory error")
    assert(fd:close())
  end,
}

test_inotify = {
  test_inotify = function()
    assert(S.mkdir(tmpfile, "RWXU")) -- do in directory so ok to run in parallel
    local fd = assert(S.inotify_init("cloexec, nonblock"))
    local wd = assert(fd:inotify_add_watch(tmpfile, "create, delete"))
    assert(S.chdir(tmpfile))
    local n, err = fd:inotify_read()
    assert(err.again, "no inotify events yet")
    assert(util.writefile(tmpfile, "test", "RWXU"))
    assert(S.unlink(tmpfile))
    n = assert(fd:inotify_read())
    assert_equal(#n, 2, "expect 2 events now")
    assert(n[1].create, "file created")
    assert_equal(n[1].name, tmpfile, "created file should have same name")
    assert(n[2].delete, "file deleted")
    assert_equal(n[2].name, tmpfile, "created file should have same name")
    assert(fd:inotify_rm_watch(wd))
    assert(fd:close())
    assert(S.chdir(".."))
    assert(S.rmdir(tmpfile))
  end,
}

test_xattr = {
  test_xattr = function()
    assert(util.writefile(tmpfile, "test", "RWXU"))
    local l, err = S.listxattr(tmpfile)
    assert(l or err.NOTSUP, "expect to get xattr or not supported on fs")
    if l then
      local fd = assert(S.open(tmpfile, "rdwr"))
      assert(#l == 0 or (#l == 1 and l[1] == "security.selinux"), "expect no xattr on new file")
      l = assert(S.llistxattr(tmpfile))
      assert(#l == 0 or (#l == 1 and l[1] == "security.selinux"), "expect no xattr on new file")
      l = assert(fd:flistxattr())
      assert(#l == 0 or (#l == 1 and l[1] == "security.selinux"), "expect no xattr on new file")
      local nn = #l
      local ok, err = S.setxattr(tmpfile, "user.test", "42", "create")
      if ok then -- likely to get err.NOTSUP here if fs not mounted with user_xattr TODO add to features
        l = assert(S.listxattr(tmpfile))
        assert(#l == nn + 1, "expect another attribute set")
        assert(S.lsetxattr(tmpfile, "user.test", "44", "replace"))
        assert(fd:fsetxattr("user.test2", "42"))
        l = assert(S.listxattr(tmpfile))
        assert(#l == nn + 2, "expect another attribute set")
        local s = assert(S.getxattr(tmpfile, "user.test"))
        assert(s == "44", "expect to read set value of xattr")
        s = assert(S.lgetxattr(tmpfile, "user.test"))
        assert(s == "44", "expect to read set value of xattr")
        s = assert(fd:fgetxattr("user.test2"))
        assert(s == "42", "expect to read set value of xattr")
        local s, err = fd:fgetxattr("user.test3")
        assert(err and err.nodata, "expect to get NODATA (=NOATTR) from non existent xattr")
        s = assert(S.removexattr(tmpfile, "user.test"))
        s = assert(S.lremovexattr(tmpfile, "user.test2"))
        l = assert(S.listxattr(tmpfile))
        assert(#l == nn, "expect no xattr now")
        local s, err = fd:fremovexattr("user.test3")
        assert(err and err.nodata, "expect to get NODATA (=NOATTR) from remove non existent xattr")
        -- table helpers
        local tt = assert(S.xattr(tmpfile))
        local n = 0
        for k, v in pairs(tt) do n = n + 1 end
        assert(n == nn, "expect no xattr now")
        tt = {}
        for k, v in pairs{test = "42", test2 = "44"} do tt["user." .. k] = v end
        assert(S.xattr(tmpfile, tt))
        tt = assert(S.lxattr(tmpfile))
        assert(tt["user.test2"] == "44" and tt["user.test"] == "42", "expect to return values set")
        n = 0
        for k, v in pairs(tt) do n = n + 1 end
        assert(n == nn + 2, "expect 2 xattr now")
        tt = {}
        for k, v in pairs{test = "42", test2 = "44", test3="hello"} do tt["user." .. k] = v end
        assert(fd:fxattr(tt))
        tt = assert(fd:fxattr())
        assert(tt["user.test2"] == "44" and tt["user.test"] == "42" and tt["user.test3"] == "hello", "expect to return values set")
        n = 0
        for k, v in pairs(tt) do n = n + 1 end
        assert(n == nn + 3, "expect 3 xattr now")
      end
      assert(fd:close())
    end
    assert(S.unlink(tmpfile))
  end,
  test_xattr_long = function()
    assert(util.touch(tmpfile))
    local l = string.rep("test", 500)
    local ok, err = S.setxattr(tmpfile, "user.test", l, "create")
    if ok then -- likely to get err.NOTSUP here if fs not mounted with user_xattr TODO add to features
      local tt = assert(S.getxattr(tmpfile, "user.test"))
      assert_equal(tt, l, "should match string")
    else assert(err.NOTSUP or err.OPNOTSUPP, "only ok error is xattr not supported, got " .. tostring(err) .. " (" .. err.errno .. ")") end
    assert(S.unlink(tmpfile))
  end,
}

test_locking = {
  test_fcntl_setlk = function()
    local fd = assert(S.open(tmpfile, "creat, rdwr", "RWXU"))
    assert(S.unlink(tmpfile))
    assert(fd:truncate(4096))
    assert(fd:fcntl("setlk", {type = "rdlck", whence = "set", start = 0, len = 4096}))
    assert(fd:close())
  end,
  test_lockf_lock = function()
    local fd = assert(S.open(tmpfile, "creat, rdwr", "RWXU"))
    assert(S.unlink(tmpfile))
    assert(fd:truncate(4096))
    assert(fd:lockf("lock", 4096))
    assert(fd:close())
  end,
  test_lockf_tlock = function()
    local fd = assert(S.open(tmpfile, "creat, rdwr", "RWXU"))
    assert(S.unlink(tmpfile))
    assert(fd:truncate(4096))
    assert(fd:lockf("tlock", 4096))
    assert(fd:close())
  end,
  test_lockf_ulock = function()
    local fd = assert(S.open(tmpfile, "creat, rdwr", "RWXU"))
    assert(S.unlink(tmpfile))
    assert(fd:truncate(4096))
    assert(fd:lockf("lock", 4096))
    assert(fd:lockf("ulock", 4096))
    assert(fd:close())
  end,
  test_lockf_test = function()
    local fd = assert(S.open(tmpfile, "creat, rdwr", "RWXU"))
    assert(S.unlink(tmpfile))
    assert(fd:truncate(4096))
    assert(fd:lockf("test", 4096))
    assert(fd:close())
  end,
}

test_tee_splice = {
  test_tee_splice = function()
    local p = assert(S.pipe("nonblock"))
    local pp = assert(S.pipe("nonblock"))
    local s = assert(S.socketpair("unix", "stream, nonblock"))
    local fd = assert(S.open(tmpfile, "rdwr, creat", "RWXU"))
    assert(S.unlink(tmpfile))

    local str = teststring

    local n = assert(fd:write(str))
    assert(n == #str)
    n = assert(S.splice(fd, 0, p[2], nil, #str, "nonblock")) -- splice file at offset 0 into pipe
    assert(n == #str)
    local n, err = S.tee(p[1], pp[2], #str, "nonblock") -- clone our pipe
    if n then
      assert(n == #str)
      n = assert(S.splice(p[1], nil, s[1], nil, #str, "nonblock")) -- splice to socket
      assert(n == #str)
      n = assert(s[2]:read())
      assert(#n == #str)
      n = assert(S.splice(pp[1], nil, s[1], nil, #str, "nonblock")) -- splice the tee'd pipe into our socket
      assert(n == #str)
      n = assert(s[2]:read())
      assert(#n == #str)
      local buf2 = t.buffer(#str)
      ffi.copy(buf2, str, #str)

      n = assert(S.vmsplice(p[2], {{buf2, #str}}, "nonblock")) -- write our memory into pipe
      assert(n == #str)
      n = assert(S.splice(p[1], nil, s[1], nil, #str, "nonblock")) -- splice out to socket
      assert(n == #str)
      n = assert(s[2]:read())
      assert(#n == #str)
    else
      assert(err.NOSYS, "only allowed error is syscall not suported, as valgrind gives this") -- TODO add to features
    end

    assert(fd:close())
    assert(p:close())
    assert(pp:close())
    assert(s:close())
  end,
}

test_timers_signals_linux = {
  test_nanosleep = function()
    local rem = assert(S.nanosleep(0.001))
    assert_equal(rem, true, "expect no elapsed time after nanosleep")
  end,
  test_alarm = function()
    assert(S.signal("alrm", "ign"))
    assert(S.alarm(10))
    assert(S.alarm(0)) -- cancel again
    assert(S.signal("alrm", "dfl"))
  end,
  test_itimer = function()
    local tt = assert(S.getitimer("real"))
    assert(tt.interval.sec == 0, "expect timer not set")
    local ss = "alrm"

    local fd = assert(S.signalfd(ss, "nonblock"))
    assert(S.sigprocmask("block", ss))

    assert(S.setitimer("real", {0, 0.01}))
    assert(S.nanosleep(0.1)) -- nanosleep does not interact with itimer

    local sig = assert(util.signalfd_read(fd))
    assert(#sig == 1, "expect one signal")
    assert(sig[1].alrm, "expect alarm clock to have rung")
    assert(fd:close())
    assert(S.sigprocmask("unblock", ss))
  end,
  test_sigprocmask = function()
    local m = assert(S.sigprocmask())
    assert(m.isemptyset, "expect initial sigprocmask to be empty")
    assert(not m.winch, "expect set empty")
    m = m:add(c.SIG.WINCH)
    assert(not m.isemptyset, "expect set not empty")
    assert(m.winch, "expect to have added SIGWINCH")
    m = m:del("WINCH, pipe")
    assert(not m.winch, "expect set empty again")
    assert(m.isemptyset, "expect initial sigprocmask to be empty")
    m = m:add("winch")
    m = assert(S.sigprocmask("block", m))
    assert(m.isemptyset, "expect old sigprocmask to be empty")
    assert(S.kill(S.getpid(), "winch")) -- should be blocked but pending
    local p = assert(S.sigpending())
    assert(p.winch, "expect pending winch")

    -- signalfd. TODO Should be in another test
    local ss = "winch, pipe, usr1, usr2"
    local fd = assert(S.signalfd(ss, "nonblock"))
    assert(S.sigprocmask("block", ss))
    assert(S.kill(S.getpid(), "usr1"))
    local ss = assert(util.signalfd_read(fd))
    assert(#ss == 2, "expect to read two signals") -- previous pending winch, plus USR1
    assert((ss[1].winch and ss[2].usr1) or (ss[2].winch and ss[1].usr1), "expect a winch and a usr1 signal") -- unordered
    assert(ss[1].user, "signal sent by user")
    assert(ss[2].user, "signal sent by user")
    assert_equal(ss[1].pid, S.getpid(), "signal sent by my pid")
    assert_equal(ss[2].pid, S.getpid(), "signal sent by my pid")
    assert(fd:close())
  end,
  test_timerfd = function()
    local fd = assert(S.timerfd_create("monotonic", "nonblock, cloexec"))
    local n = assert(util.timerfd_read(fd))
    assert(n == 0, "no timer events yet")
    assert(fd:block())
    local o = assert(fd:timerfd_settime(nil, {0, 0.000001}))
    assert(o.interval.time == 0 and o.value.time == 0, "old timer values zero")
    n = assert(util.timerfd_read(fd))
    assert(n == 1, "should have exactly one timer expiry")
    local o = assert(fd:timerfd_gettime())
    assert_equal(o.interval.time, 0, "expect 0 from gettime as expired")
    assert_equal(o.value.time, 0, "expect 0 from gettime as expired")
    assert(fd:close())
  end,
  test_gettimeofday = function()
    local tv = assert(S.gettimeofday())
    assert(math.floor(tv.time) == tv.sec, "should be able to get float time from timeval")
  end,
  test_time = function()
    local tt = S.time()
  end,
  test_clock = function()
    local tt = assert(S.clock_getres("realtime"))
    local tt = assert(S.clock_gettime("realtime"))
    -- TODO add settime
  end,
  test_clock_nanosleep = function()
    local rem = assert(S.clock_nanosleep("realtime", nil, 0.001))
    assert_equal(rem, true, "expect no elapsed time after clock_nanosleep")
  end,
  test_clock_nanosleep_abs = function()
    local rem = assert(S.clock_nanosleep("realtime", "abstime", 0)) -- in the past
    assert_equal(rem, true, "expect no elapsed time after clock_nanosleep")
  end,
  test_sigaction_ucontext = function() -- this test does not do much yet
    local sig = t.int1(0)
    local pid = t.int32_1(0)
    local f = t.sa_sigaction(function(s, info, uc)
      local ucontext = pt.ucontext(uc)
      sig[0] = s
      pid[0] = info.pid
      local mcontext = ucontext.uc_mcontext
    end)
    assert(S.sigaction("pipe", {sigaction = f}))
    assert(S.kill(S.getpid(), "pipe"))
    assert(S.sigaction("pipe", "dfl"))
    assert_equal(sig[0], c.SIG.PIPE)
    assert_equal(pid[0], S.getpid())
    f:free() -- free ffi slot for function
  end,
  test_sigaction_function_handler = function()
    local sig = t.int1(0)
    local f = t.sighandler(function(s) sig[0] = s end)
    assert(S.sigaction("pipe", {handler = f}))
    assert(S.kill(S.getpid(), "pipe"))
    assert(S.sigaction("pipe", "dfl"))
    assert_equal(sig[0], c.SIG.PIPE)
    f:free() -- free ffi slot for function
  end,
  test_sigaction_function_sigaction = function()
    local sig = t.int1(0)
    local pid = t.int32_1(0)
    local f = t.sa_sigaction(function(s, info, ucontext)
      sig[0] = s
      pid[0] = info.pid
    end)
    assert(S.sigaction("pipe", {sigaction = f}))
    assert(S.kill(S.getpid(), "pipe"))
    assert(S.sigaction("pipe", "dfl"))
    assert_equal(sig[0], c.SIG.PIPE)
    assert_equal(pid[0], S.getpid())
    f:free() -- free ffi slot for function
  end,
}

test_mmap = {
  test_mmap_fail = function()
    local size = 4096
    local mem, err = S.mmap(pt.void(1), size, "read", "fixed, anonymous", -1, 0)
    assert(err, "expect non aligned fixed map to fail")
    assert(err.INVAL, "expect non aligned map to return EINVAL")
  end,
  test_mmap = function()
    local size = 4096
    local mem = assert(S.mmap(nil, size, "read", "private, anonymous", -1, 0))
    assert(S.munmap(mem, size))
  end,
  test_msync = function()
    local size = 4096
    local mem = assert(S.mmap(nil, size, "read", "private, anonymous", -1, 0))
    assert(S.msync(mem, size, "sync"))
    assert(S.munmap(mem, size))
  end,
  test_madvise = function()
    local size = 4096
    local mem = assert(S.mmap(nil, size, "read", "private, anonymous", -1, 0))
    assert(S.madvise(mem, size, "random"))
    assert(S.munmap(mem, size))
  end,
  test_mlock = function()
    local size = 4096
    local mem = assert(S.mmap(nil, size, "read", "private, anonymous", -1, 0))
    assert(S.mlock(mem, size))
    assert(S.munlock(mem, size))
    assert(S.munmap(mem, size))
    local ok, err = S.mlockall("current")
    assert(ok or err.nomem, "expect mlockall to succeed, or fail due to rlimit")
    assert(S.munlockall())
    assert(S.munmap(mem, size))
  end
}

test_mremap = { -- differs in prototype by OS
  test_mremap = function()
    local size = 4096
    local size2 = size * 2
    local mem = assert(S.mmap(nil, size, "read", "private, anonymous", -1, 0))
    mem = assert(S.mremap(mem, size, size2, "maymove"))
    assert(S.munmap(mem, size2))
  end,
}

test_misc = {
  test_umask = function()
    local mask
    mask = S.umask("WGRP, WOTH")
    mask = S.umask("WGRP, WOTH")
    assert_equal(mask, c.MODE.WGRP + c.MODE.WOTH, "umask not set correctly")
  end,
  test_sysinfo = function()
    local i = assert(S.sysinfo()) -- TODO test values returned for some sanity
  end,
  test_sysctl = function()
    local syslog = assert(S.syslog(10))
    assert(syslog > 1, "syslog buffer should have positive size")
  end,
  test_rlimit = function()
    local r, err = S.getrlimit("nofile")
    -- new travis CI does not support this TODO add to features
    if err and err.NOSYS then return end
    assert(not err, "expect no error, got " .. tostring(err))
    assert(S.setrlimit("nofile", {0, r.rlim_max}))
    local fd, err = S.open("/dev/zero", "rdonly")
    assert(err.MFILE, "should be over rlimit")
    assert(S.setrlimit("nofile", r)) -- reset
    fd = assert(S.open("/dev/zero", "rdonly"))
    assert(fd:close())
  end,
  test_prlimit = function()
    local r, err = S.prlimit(0, "nofile")
    -- new travis CI does not support this TODO add to features
    if err and err.NOSYS then return end
    assert(not err, "expect no error")
    local r2 = assert(S.prlimit(0, "nofile", {512, r.max}))
    assert_equal(r2.cur, r.cur, "old value same")
    assert_equal(r2.max, r.max, "old value same")
    local r3 = assert(S.prlimit(0, "nofile"))
    assert_equal(r3.cur, 512, "new value 512")
    assert_equal(r3.max, r.max, "max unchanged")
    assert(S.prlimit(0, "nofile", r))
    local r4 = assert(S.prlimit(0, "nofile"))
    assert_equal(r4.cur, r.cur, "reset to original")
    assert_equal(r4.max, r.max, "reset to original")
  end,
  test_prlimit_root = function()
    local r = assert(S.prlimit(0, "nofile"))
    local r2 = assert(S.prlimit(0, "nofile", {512, 640}))
    assert_equal(r2.cur, r.cur, "old value same")
    assert_equal(r2.max, r.max, "old value same")
    local r3 = assert(S.prlimit(0, "nofile"))
    assert_equal(r3.cur, 512, "new value 512")
    assert_equal(r3.max, 640, "max unchanged")
    local ok, err = S.prlimit(0, "nofile", {"infinity", "infinity"})
    assert(not ok and err.PERM, "should not be allowed to unlimit completely")
    assert(S.prlimit(0, "nofile", r))
    local r4 = assert(S.prlimit(0, "nofile"))
    assert_equal(r4.cur, r.cur, "reset to original")
    assert_equal(r4.max, r.max, "reset to original")
  end,
  test_adjtimex = function()
    local tt = assert(S.adjtimex())
  end,
  test_prctl = function()
    local n
    n = assert(S.prctl("capbset_read", "mknod"))
    assert(n == 0 or n == 1, "capability may or may not be set")
    local nn = assert(S.prctl("get_dumpable"))
    assert(S.prctl("set_dumpable", 0))
    n = assert(S.prctl("get_dumpable"))
    assert(n == 0, "process not dumpable after change")
    assert(S.prctl("set_dumpable", nn))
    n = assert(S.prctl("get_keepcaps"))
    assert(n == 0, "process keepcaps defaults to 0")
    n = assert(S.prctl("get_pdeathsig"))
    assert(n == 0, "process pdeathsig defaults to 0")
    assert(S.prctl("set_pdeathsig", "winch"))
    n = assert(S.prctl("get_pdeathsig"))
    assert(n == c.SIG.WINCH, "process pdeathsig should now be set to winch")
    assert(S.prctl("set_pdeathsig")) -- reset
    n = assert(S.prctl("get_name"))
    assert(S.prctl("set_name", "test"))
    n = assert(S.prctl("get_name"))
    assert(n == "test", "name should be as set")
    -- failing in travis CI now, as file does not exist
    --n = assert(util.readfile("/proc/self/comm"))
    --assert(n == "test\n", "comm should be as set")
  end,
  test_uname = function()
    local u = assert(S.uname())
    assert_string(u.nodename)
    assert_string(u.sysname)
    assert_string(u.release)
    assert_string(u.version)
    assert_string(u.machine)
    assert_string(u.domainname)
  end,
  test_gethostname = function()
    local h = assert(S.gethostname())
    local u = assert(S.uname())
    assert_equal(h, u.nodename, "gethostname did not return nodename")
  end,
  test_getdomainname = function()
    local d = assert(S.getdomainname())
    local u = assert(S.uname())
    assert_equal(d, u.domainname, "getdomainname did not return domainname")
  end,
  test_sethostname_root = function()
    assert(S.sethostname("hostnametest"))
    assert_equal(S.gethostname(), "hostnametest")
  end,
  test_setdomainname_root = function()
    assert(S.setdomainname("domainnametest"))
    assert_equal(S.getdomainname(), "domainnametest")
  end,
}

test_sendfile = {
  test_sendfile = function()
    local f1 = assert(S.open(tmpfile, "rdwr,creat", "rwxu"))
    local f2 = assert(S.open(tmpfile2, "rdwr,creat", "rwxu"))
    assert(S.unlink(tmpfile))
    assert(f1:truncate(30))
    assert(f2:truncate(30))
    local off = 0
    local n = assert(f1:sendfile(f2, off, 16))
    assert(n.count == 16 and n.offset == 16, "sendfile should send 16 bytes")
    assert(f1:close())
    assert(f2:close())
  end,
}

test_raw_socket = {
  test_ip_checksum = function()
    local packet = {0x45, 0x00,
      0x00, 0x73, 0x00, 0x00,
      0x40, 0x00, 0x40, 0x11,
      0xb8, 0x61, 0xc0, 0xa8, 0x00, 0x01,
      0xc0, 0xa8, 0x00, 0xc7}

    local expected = 0x61B8 -- note reversed from example at https://en.wikipedia.org/wiki/IPv4_header_checksum#Example:_Calculating_a_checksum due to byte order issue

    local buf = t.buffer(#packet, packet)
    local iphdr = pt.iphdr(buf)
    iphdr[0].check = 0
    local cs = iphdr[0]:checksum()
    assert(cs == expected, "expect correct ip checksum: " .. string.format("%%%04X", cs) .. " " .. string.format("%%%04X", expected))
  end,
  test_raw_udp_root = function() -- TODO create some helper functions, this is not very nice

    local h = require "syscall.helpers" -- TODO should not have to use later

    local loop = "127.0.0.1"
    local raw = assert(S.socket("inet", "raw", "raw"))
    local msg = "raw message."
    local udplen = s.udphdr + #msg
    local len = s.iphdr + udplen
    local buf = t.buffer(len)
    local iphdr = pt.iphdr(buf)
    local udphdr = pt.udphdr(buf + s.iphdr)
    ffi.copy(buf + s.iphdr + s.udphdr, msg, #msg)
    local bound = false
    local sport = 666
    local sa = t.sockaddr_in(sport, loop)

    local buf2 = t.buffer(#msg)

    local cl = assert(S.socket("inet", "dgram"))
    local ca = t.sockaddr_in(0, loop)
    assert(cl:bind(ca))
    local ca = cl:getsockname()
    local cport = ca.port

    -- TODO iphdr should have __index helpers for endianness etc (note use raw s_addr)
    iphdr[0] = {ihl = 5, version = 4, tos = 0, id = 0, frag_off = h.htons(0x4000), ttl = 64, protocol = c.IPPROTO.UDP, check = 0,
             saddr = sa.sin_addr.s_addr, daddr = ca.sin_addr.s_addr, tot_len = h.htons(len)}
    iphdr[0]:checksum()

    -- test checksum TODO new test
    cport = 777

    --udphdr[0] = {src = sport, dst = cport, length = udplen} -- doesnt work with metamethods
    udphdr[0].src = sport
    udphdr[0].dst = cport
    udphdr[0].length = udplen
    udphdr[0]:checksum(iphdr[0], buf + s.iphdr + s.udphdr)

    assert_equal(udphdr[0].check, 0x306b) -- reversed due to network order

    cport = ca.port
    udphdr[0].dst = cport
    udphdr[0]:checksum(iphdr[0], buf + s.iphdr + s.udphdr)

    local n = assert(raw:sendto(buf, len, 0, ca))
    local f = assert(cl:recvfrom(buf2, #msg))

    assert_equal(f.count, #msg)

    assert(raw:close())
    assert(cl:close())

  end,

}

test_netlink = {
  test_getlink = function()
    local i = assert(nl.getlink())
    local df = assert(util.ls("/sys/class/net", true))
    assert_equal(#df, #i, "expect same number of interfaces as /sys/class/net")
    assert(i.lo, "expect a loopback interface")
    local lo = i.lo
    assert(lo.flags.up, "loopback interface should be up")
    assert(lo.flags.loopback, "loopback interface should be marked as loopback")
    assert(lo.flags.running, "loopback interface should be running")
    assert(not lo.flags.broadcast, "loopback interface should not be broadcast")
    assert(not lo.flags.multicast, "loopback interface should not be multicast")
    assert_equal(tostring(lo.macaddr), "00:00:00:00:00:00", "null hardware address on loopback")
    assert(lo.loopback, "loopback interface type should be loopback") -- TODO add getflag
    assert(lo.mtu >= 16436, "expect lo MTU at least 16436")
    local eth = i.eth0 or i.eth1 -- may not exist
    if eth then
      assert(eth.flags.broadcast, "ethernet interface should be broadcast")
      assert(eth.flags.multicast, "ethernet interface should be multicast")
      assert(eth.ether, "ethernet interface type should be ether")
      assert_equal(eth.addrlen, 6, "ethernet hardware address length is 6")
      local mac = assert(util.readfile("/sys/class/net/" .. eth.name .. "/address"), "expect eth to have address file in /sys")
      assert_equal(tostring(eth.macaddr) .. '\n', mac, "mac address hsould match that from /sys")
      assert_equal(tostring(eth.broadcast), 'ff:ff:ff:ff:ff:ff', "ethernet broadcast mac")
      local mtu = assert(util.readfile("/sys/class/net/" .. eth.name .. "/mtu"), "expect eth to have mtu in /sys")
      assert_equal(eth.mtu, tonumber(mtu), "expect ethernet MTU to match /sys")
    end
    local wlan = i.wlan0
    if wlan then
      assert(wlan.ether, "wlan interface type should be ether")
      assert_equal(wlan.addrlen, 6, "wireless hardware address length is 6")
      local mac = assert(util.readfile("/sys/class/net/" .. wlan.name .. "/address"), "expect wlan to have address file in /sys")
      assert_equal(tostring(wlan.macaddr) .. '\n', mac, "mac address should match that from /sys")
    end
  end,
  test_get_addresses_in = function()
    local as = assert(nl.getaddr("inet"))
    local lo = assert(nl.getlink()).lo.index
    for i = 1, #as do
      if as[i].index == lo then
        assert_equal(tostring(as[i].addr), "127.0.0.1", "loopback ipv4 on lo")
      end
    end
  end,
  test_get_addresses_in6 = function()
    local as = assert(nl.getaddr("inet6"))
    local lo = assert(nl.getlink()).lo.index
    for i = 1, #as do
      if as[i].index == lo then
        assert_equal(tostring(as[i].addr), "::1", "loopback ipv6 on lo") -- allow fail if no ipv6
      end
    end
  end,
  test_interfaces = function()
    local i = nl.interfaces()
    assert_equal(tostring(i.lo.inet[1].addr), "127.0.0.1", "loopback ipv4 on lo")
    assert_equal(tostring(i.lo.inet6[1].addr), "::1", "loopback ipv6 on lo")
  end,
  test_newlink_flags_root = function()
    local p = assert(S.clone())
     if p == 0 then
      fork_assert(S.unshare("newnet"))
      local i = fork_assert(nl.interfaces())
      fork_assert(i.lo and not i.lo.flags.up, "expect new network ns has down lo interface")
      fork_assert(nl.newlink(i.lo.index, 0, "up", "up"))
      local lo = fork_assert(i.lo:refresh())
      fork_assert(lo.flags.up, "expect lo up now")
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
  end,
  test_interface_up_down_root = function()
    local i = assert(nl.interfaces())
    assert(i.lo:down())
    assert(not i.lo.flags.up, "expect lo down")
    assert(i.lo:up())
    assert(i.lo.flags.up, "expect lo up now")
  end,
  test_interface_setflags_root = function()
    local p = assert(S.clone())
     if p == 0 then
      fork_assert(S.unshare("newnet"))
      local i = fork_assert(nl.interfaces())
      fork_assert(i.lo, "expect new network ns has lo interface")
      fork_assert(not i.lo.flags.up, "expect new network lo is down")
      fork_assert(i.lo:setflags("up"))
      fork_assert(i.lo.flags.up, "expect lo up now")
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
  end,
  test_interface_set_mtu_root = function()
    local i = assert(nl.interfaces())
    local lo = assert(i.lo, "expect lo interface")
    assert(lo:up())
    assert(lo.flags.up, "expect lo up now")
    local mtu = lo.mtu
    assert(lo:setmtu(16000))
    assert_equal(lo.mtu, 16000, "expect MTU now 16000")
    assert(lo:setmtu(mtu))
  end,
  test_interface_set_mtu_byname_root = function()
    local i = assert(nl.interfaces())
    local lo = assert(i.lo, "expect lo interface")
    local mtu = lo.mtu
    assert(lo:up())
    assert(nl.newlink(0, 0, "up", "up", "ifname", "lo", "mtu", 16000))
    assert(lo:refresh())
    assert_equal(lo.mtu, 16000, "expect MTU now 16000")
    assert(lo.flags.up, "expect lo up now")
    assert(lo:setmtu(mtu))
  end,
  test_interface_rename_root = function()
    assert(nl.create_interface{name = "dummy0", type = "dummy"})
    local i = assert(nl.interfaces())
    assert(i.dummy0)
    assert(i.dummy0:rename("newname"))
    assert(i:refresh())
    assert(i.newname and not i.dummy0, "interface should be renamed")
    assert(i.newname:delete())
  end,
  test_interface_set_macaddr_root = function()
    assert(nl.create_interface{name = "dummy0", type = "dummy"})
    local i = assert(nl.interfaces())
    assert(i.dummy0)
    assert(i.dummy0:setmac("46:9d:c9:06:dd:dd"))
    assert_equal(tostring(i.dummy0.macaddr), "46:9d:c9:06:dd:dd", "interface should have new mac address")
    assert(i.dummy0:down())
    assert(i.dummy0:delete())
  end,
  test_interface_set_macaddr_fail = function()
    local i = assert(nl.interfaces())
    assert(i.lo, "expect to find lo")
    local ok, err = nl.newlink(i.lo.index, 0, 0, 0, "address", "46:9d:c9:06:dd:dd")
    assert(not ok and err and (err.PERM or err.OPNOTSUPP), "should not be able to change macaddr on lo")
  end,
  test_newlink_error_root = function()
    local ok, err = nl.newlink(-1, 0, "up", "up")
    assert(not ok, "expect bogus newlink to fail")
    assert(err.NODEV, "expect no such device error")
  end,
  test_newlink_newif_dummy_root = function()
    local ok, err = nl.create_interface{name = "dummy0", type = "dummy"}
    local i = assert(nl.interfaces())
    assert(i.dummy0, "expect dummy interface")
    assert(i.dummy0:delete())
  end,
  test_newlink_newif_bridge_root = function()
    assert(nl.create_interface{name = "br0", type = "bridge"})
    local i = assert(nl.interfaces())
    assert(i.br0, "expect bridge interface")
    local b = assert(util.bridge_list())
    assert(b.br0, "expect to find new bridge")
    assert(i.br0:delete())
  end,
  test_dellink_by_name_root = function()
    assert(nl.create_interface{name = "dummy0", type = "dummy"})
    local i = assert(nl.interfaces())
    assert(i.dummy0, "expect dummy interface")
    assert(nl.dellink(0, "ifname", "dummy0"))
    local i = assert(nl.interfaces())
    assert(not i.dummy0, "expect dummy interface gone")
  end,
  test_broadcast = function()
    assert_equal(tostring(nl.broadcast("0.0.0.0", 32)), "0.0.0.0")
    assert_equal(tostring(nl.broadcast("10.10.20.1", 24)), "10.10.20.255")
    assert_equal(tostring(nl.broadcast("0.0.0.0", 0)), "255.255.255.255")
  end,
  test_newaddr6_root = function()
    local lo = assert(nl.interface("lo"))
    assert(nl.newaddr(lo, "inet6", 128, "permanent", "local", "::2"))
    assert(lo:refresh())
    assert_equal(#lo.inet6, 2, "expect two inet6 addresses on lo now")
    if tostring(lo.inet6[1].addr) == "::1"
      then assert_equal(tostring(lo.inet6[2].addr), "::2")
      else assert_equal(tostring(lo.inet6[1].addr), "::2")
    end
    assert_equal(lo.inet6[2].prefixlen, 128, "expect /128")
    assert_equal(lo.inet6[1].prefixlen, 128, "expect /128")
    assert(nl.deladdr(lo.index, "inet6", 128, "address", "::2"))
    assert(lo:refresh())
    assert_equal(#lo.inet6, 1, "expect one inet6 addresses on lo now")
    assert_equal(tostring(lo.inet6[1].addr), "::1", "expect only ::1 now")
    -- TODO this leaves a route to ::2 which we should delete
  end,
  test_newaddr_root = function()
    local ok, err = nl.create_interface{name = "dummy0", type = "dummy"}
    local i = assert(nl.interfaces())
    assert(i.dummy0:up())
    local af, netmask, address, bcast = c.AF.INET, 24, t.in_addr("10.10.10.1"), t.in_addr("10.10.10.255")
    assert(nl.newaddr(i.dummy0.index, af, netmask, "permanent", "local", address, "broadcast", bcast))
    assert(i:refresh())
    assert_equal(#i.dummy0.inet, 1, "expect one address now")
    assert_equal(tostring(i.dummy0.inet[1].addr), "10.10.10.1")
    assert_equal(tostring(i.dummy0.inet[1].broadcast), "10.10.10.255")
    assert(i.dummy0:delete())
  end,
  test_newaddr_helper_root = function()
    local ok, err = nl.create_interface{name = "dummy0", type = "dummy"}
    local i = assert(nl.interfaces())
    assert(i.dummy0:up())
    assert(i.dummy0:address("10.10.10.1/24"))
    assert(i.dummy0:refresh())
    assert_equal(#i.dummy0.inet, 1, "expect one address now")
    assert_equal(tostring(i.dummy0.inet[1].addr), "10.10.10.1")
    assert_equal(tostring(i.dummy0.inet[1].broadcast), "10.10.10.255")
    assert(i.dummy0:delete())
  end,
  test_newaddr6_helper_root = function()
    local lo = assert(nl.interface("lo"))
    assert(lo:address("::2/128"))
    assert(lo:refresh())
    assert_equal(#lo.inet6, 2, "expect two inet6 addresses on lo now")
    if tostring(lo.inet6[1].addr) == "::1"
      then assert_equal(tostring(lo.inet6[2].addr), "::2")
      else assert_equal(tostring(lo.inet6[1].addr), "::2")
    end
    assert_equal(lo.inet6[2].prefixlen, 128, "expect /128")
    assert_equal(lo.inet6[1].prefixlen, 128, "expect /128")
    assert(lo:deladdress("::2"))
    assert_equal(#lo.inet6, 1, "expect one inet6 addresses on lo now")
    assert_equal(tostring(lo.inet6[1].addr), "::1", "expect only ::1 now")
    -- TODO this leaves a route to ::2 which we should delete
  end,
  test_getroute_inet = function()
    local r = assert(nl.routes("inet", "unspec"))
    local nr = r:match("127.0.0.0/32")
    assert_equal(#nr, 1, "expect 1 route")
    local lor = nr[1]
    assert_equal(tostring(lor.source), "0.0.0.0", "expect empty source route")
    assert_equal(lor.output, "lo", "expect to be on lo")
  end,
  test_getroute_inet6 = function()
    local r = assert(nl.routes("inet6", "unspec"))
    local nr = r:match("::1/128")
    assert(#nr >= 1, "expect at least one matched route") -- one of my machines has two
    local lor = nr[1]
    assert_equal(tostring(lor.source), "::", "expect empty source route")
    assert_equal(lor.output, "lo", "expect to be on lo")
  end,
  test_newroute_inet6_root = function()
    local r = assert(nl.routes("inet6", "unspec"))
    local lo = assert(nl.interface("lo"))
    assert(nl.newroute("create", {family = "inet6", dst_len = 128, type = "unicast", protocol = "static"}, "dst", "::3", "oif", lo.index))
    r:refresh()
    local nr = r:match("::3/128")
    assert_equal(#nr, 1, "expect to find new route")
    nr = nr[1]
    assert_equal(nr.oif, lo.index, "expect route on lo")
    assert_equal(nr.output, "lo", "expect route on lo")
    assert_equal(nr.dst_len, 128, "expect /128")
    assert(nl.delroute({family = "inet6", dst_len = 128}, "dst", "::3", "oif", lo.index))
    r:refresh()
    local nr = r:match("::3/128")
    assert_equal(#nr, 0, "expect route deleted")
  end,
  test_netlink_events_root = function()
    local sock = assert(nl.socket("route", {groups = "link"}))
    assert(nl.create_interface{name = "dummy1", type = "dummy"})
    local m = assert(nl.read(sock))
    assert(m.dummy1, "should find dummy 1 in returned info")
    assert_equal(m.dummy1.op, "newlink", "new interface")
    assert(m.dummy1.newlink, "new interface")
    assert(m.dummy1:setmac("46:9d:c9:06:dd:dd"))
    assert(m.dummy1:delete())
    local m = assert(nl.read(sock))
    assert(m.dummy1, "should get info about deleted interface")
    assert_equal(tostring(m.dummy1.macaddr), "46:9d:c9:06:dd:dd", "should get address that was set")
    assert(sock:close())
  end,
  test_move_interface_ns_root = function()
    assert(nl.create_interface{name = "dummy0", type = "dummy"})
    local i = assert(nl.interfaces())
    assert(i.dummy0, "expect dummy0 interface")
    local p = assert(S.clone("newnet"))
    if p == 0 then
      local sock = assert(nl.socket("route", {groups = "link"}))
      local i = fork_assert(nl.interfaces())
      if not i.dummy0 then
        local m = assert(nl.read(sock))
        fork_assert(m.dummy0, "expect dummy0 appeared")
      end
      fork_assert(sock:close())
      local i = fork_assert(nl.interfaces())
      fork_assert(i.dummy0, "expect dummy0 interface in child")
      fork_assert(i.dummy0:delete())
      fork_assert(i:refresh())
      fork_assert(not i.dummy0, "expect no dummy if")
      S.exit()
    else
      assert(i.dummy0:move_ns(p))
      assert(i:refresh())
      assert(not i.dummy0, "expect dummy0 vanished")
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
  end,
  test_netlink_veth_root = function()
    assert(nl.newlink(0, "create", 0, 0, "linkinfo", {"kind", "veth", "data", {"peer", {t.ifinfomsg, {}, "ifname", "veth1"}}}, "ifname", "veth0"))
    local i = assert(nl.interfaces())
    assert(i.veth0, "expect veth0")
    assert(i.veth1, "expect veth1")
    assert(nl.dellink(0, "ifname", "veth0"))
    assert(i:refresh())
    assert(not i.veth0, "expect no veth0")
    assert(not i.veth1, "expect no veth1")
  end,
  test_create_veth_root = function()
    -- TODO create_interface version
    assert(nl.create_interface{name = "veth0", type = "veth", peer = {name = "veth1"}})
    local i = assert(nl.interfaces())
    assert(i.veth0, "expect veth0")
    assert(i.veth1, "expect veth1")
    assert(nl.dellink(0, "ifname", "veth0"))
    assert(i:refresh())
    assert(not i.veth0, "expect no veth0")
    assert(not i.veth1, "expect no veth1")
  end,
  test_newneigh_root = function()
    assert(nl.create_interface{name = "dummy0", type = "dummy"})
    local i = assert(nl.interfaces())
    assert(i.dummy0:up())
    assert(i.dummy0:address("10.0.0.1/32"))
    assert(nl.newneigh(i.dummy0, {family = "inet", state = "permanent"}, "dst", "10.0.0.2", "lladdr", "46:9d:c9:06:dd:dd"))
    local n = assert(nl.getneigh(i.dummy0, {family = "inet"}, "dst", "10.0.0.2", "lladdr", "46:9d:c9:06:dd:dd"))
    assert_equal(#n, 1)
    assert_equal(tostring(n[1].lladdr), "46:9d:c9:06:dd:dd")
    assert_equal(tostring(n[1].dst), "10.0.0.2")
    assert(nl.delneigh(i.dummy0, {family = "inet"}, "dst", "10.0.0.2", "lladdr", "46:9d:c9:06:dd:dd"))
    assert(i.dummy0:delete())
  end,
}

test_termios = {
  test_pts_termios = function()
    local ptm = assert(util.posix_openpt("rdwr, noctty"))
    assert(ptm:grantpt())
    assert(ptm:unlockpt())
    local pts_name = assert(ptm:ptsname())
    local pts = assert(util.open_pts(pts_name, "rdwr, noctty"))
    assert(pts:isatty(), "should be a tty")
    local termios = assert(pts:tcgetattr())
    assert(termios:cfgetospeed() ~= 115200)
    termios:cfsetspeed(115200)
    assert_equal(termios:cfgetispeed(), 115200, "expect input speed as set")
    assert_equal(termios:cfgetospeed(), 115200, "expect output speed as set")
    assert(bit.band(termios.c_lflag, c.LFLAG.ICANON) ~= 0)
    termios:cfmakeraw()
    assert(bit.band(termios.c_lflag, c.LFLAG.ICANON) == 0)
    assert(pts:tcsetattr("now", termios))
    termios = assert(pts:tcgetattr())
    assert(termios:cfgetospeed() == 115200)
    assert(bit.band(termios.c_lflag, c.LFLAG.ICANON) == 0)
    assert(pts:tcsendbreak(0))
    assert(pts:tcdrain())
    assert(pts:tcflush('ioflush'))
    assert(pts:tcflow('ooff'))
    assert(pts:tcflow('ioff'))
    assert(pts:tcflow('oon'))
    assert(pts:tcflow('ion'))
    assert(pts:close())
    assert(ptm:close())
    assert_equal(pts:getfd(), -1, "fd should be closed")
    assert_equal(ptm:getfd(), -1, "fd should be closed")
  end,
  test_isatty_fail = function()
    local fd = S.open("/dev/zero")
    assert(not util.isatty(fd), "not a tty")
    assert(fd:close())
  end,
}

test_poll_select = {
  test_poll = function()
    local sv = assert(S.socketpair("unix", "stream"))
    local a, b = sv[1], sv[2]
    local pev = {{fd = a, events = "in"}}
    local p = assert(S.poll(pev, 0))
    assert(p[1].fd == a:getfd() and p[1].revents == 0, "no events")
    assert(b:write(teststring))
    local p = assert(S.poll(pev, 0))
    assert(p[1].fd == a:getfd() and p[1].IN, "one event now")
    assert(a:read())
    assert(b:close())
    assert(a:close())
  end,
  test_select = function()
    local sv = assert(S.socketpair("unix", "stream"))
    local a, b = sv[1], sv[2]
    local sel = assert(S.select{readfds = {a, b}, timeout = t.timeval(0,0)})
    assert(sel.count == 0, "nothing to read select now")
    assert(b:write(teststring))
    sel = assert(S.select{readfds = {a, b}, timeout = {0, 0}})
    assert(sel.count == 1, "one fd available for read now")
    assert(b:close())
    assert(a:close())
  end,
}

test_ppoll_pselect = {
  test_ppoll = function()
    local sv = assert(S.socketpair("unix", "stream"))
    local a, b = sv[1], sv[2]
    local pev = {{fd = a, events = c.POLL.IN}}
    local p = assert(S.ppoll(pev, 0, nil))
    assert(p[1].fd == a:getfd() and p[1].revents == 0, "one event now")
    assert(b:write(teststring))
    local p = assert(S.ppoll(pev, nil, "alrm"))
    assert(p[1].fd == a:getfd() and p[1].IN, "one event now")
    assert(a:read())
    assert(b:close())
    assert(a:close())
  end,
  test_pselect = function()
    local sv = assert(S.socketpair("unix", "stream"))
    local a, b = sv[1], sv[2]
    local sel = assert(S.pselect{readfds = {1, b}, timeout = 0, sigset = "alrm"})
    assert(sel.count == 0, "nothing to read select now")
    assert(b:write(teststring))
    sel = assert(S.pselect{readfds = {a, b}, timeout = 0, sigset = sel.sigset})
    assert(sel.count == 1, "one fd available for read now")
    assert(b:close())
    assert(a:close())
  end,
}

test_events_epoll = {
  test_eventfd = function()
    local fd = assert(S.eventfd(0, "nonblock"))
    local n = assert(util.eventfd_read(fd))
    assert_equal(n, 0, "eventfd should return 0 initially")
    assert(util.eventfd_write(fd, 3))
    assert(util.eventfd_write(fd, 6))
    assert(util.eventfd_write(fd, 1))
    n = assert(util.eventfd_read(fd))
    assert_equal(n, 10, "eventfd should return 10")
    n = assert(util.eventfd_read(fd))
    assert(n, 0, "eventfd should return 0 again")
    assert(fd:close())
  end,
  test_epoll = function()
    local sv = assert(S.socketpair("unix", "stream"))
    local a, b = sv[1], sv[2]
    local ep = assert(S.epoll_create("cloexec"))
    assert(ep:epoll_ctl("add", a, "in"))
    local r = assert(ep:epoll_pwait(nil, 1, 0))
    assert(#r == 0, "no events yet")
    assert(b:write(teststring))
    r = assert(ep:epoll_wait())
    assert(#r == 1, "one event now")
    assert(r[1].IN, "read event")
    assert(r[1].fd == a:getfd(), "expect to get fd of ready file back") -- by default our epoll_ctl sets this
    assert(ep:close())
    assert(a:read()) -- clear event
    assert(b:close())
    assert(a:close())
  end
}

test_aio = {
  teardown = clean,
  test_aio_setup = function()
    local ctx = assert(S.io_setup(8))
    assert(S.io_destroy(ctx))
  end,
--[[ -- temporarily disabled gc and methods on aio
  test_aio_ctx_gc = function()
    local ctx = assert(S.io_setup(8))
    local ctx2 = t.aio_context()
    ffi.copy(ctx2, ctx, s.aio_context)
    ctx = nil
    collectgarbage("collect")
    local ok, err = S.io_destroy(ctx2)
    assert(not ok, "should have closed aio ctx")
  end,
]]
  test_aio = function()
    local abuf = assert(S.mmap(nil, 4096, "read, write", "private, anonymous", -1, 0))
    ffi.copy(abuf, teststring)
    local fd = S.open(tmpfile, "creat, direct, rdwr", "RWXU") -- use O_DIRECT or aio may not work
    assert(S.unlink(tmpfile))
    assert(fd:pwrite(abuf, 4096, 0))
    ffi.fill(abuf, 4096)
    local ctx = assert(S.io_setup(8))
    local a = t.iocb_array{{opcode = "pread", data = 42, fildes = fd, buf = abuf, nbytes = 4096, offset = 0}}
    local ret = assert(S.io_submit(ctx, a))
    assert_equal(ret, 1, "expect one event submitted")
    local r = assert(S.io_getevents(ctx, 1, 1))
    assert_equal(#r, 1, "expect one aio event") -- TODO test what is returned
    assert_equal(r[1].data, 42, "expect to get our data back")
    assert_equal(r[1].res, 4096, "expect to get full read")
    assert(fd:close())
    assert(S.munmap(abuf, 4096))
  end,
  test_aio_cancel = function()
    local abuf = assert(S.mmap(nil, 4096, "read, write", "private, anonymous", -1, 0))
    ffi.copy(abuf, teststring)
    local fd = S.open(tmpfile, "creat, direct, rdwr", "RWXU")
    assert(S.unlink(tmpfile))
    assert(fd:pwrite(abuf, 4096, 0))
    ffi.fill(abuf, 4096)
    local ctx = assert(S.io_setup(8))
    local a = t.iocb_array{{opcode = "pread", data = 42, fildes = fd, buf = abuf, nbytes = 4096, offset = 0}}
    local ret = assert(S.io_submit(ctx, a))
    assert_equal(ret, 1, "expect one event submitted")
    -- erroring, giving EINVAL which is odd, man page says means ctx invalid TODO fix
    --local ok = assert(S.io_cancel(ctx, a.iocbs[1]))
    --r = assert(S.io_getevents(ctx, 1, 1))
    --assert_equal(r, 0, "expect no aio events")
    assert(S.io_destroy(ctx))
    assert(fd:close())
    assert(S.munmap(abuf, 4096))
  end,
  test_aio_eventfd = function()
    local abuf = assert(S.mmap(nil, 4096, "read, write", "private, anonymous", -1, 0))
    ffi.copy(abuf, teststring)
    local fd = S.open(tmpfile, "creat, direct, rdwr", "RWXU") -- need to use O_DIRECT for aio to work
    assert(S.unlink(tmpfile))
    assert(fd:pwrite(abuf, 4096, 0))
    ffi.fill(abuf, 4096)
    local ctx = assert(S.io_setup(8))
    local efd = assert(S.eventfd())
    local ep = assert(S.epoll_create())
    assert(ep:epoll_ctl("add", efd, "in"))
    local a = t.iocb_array{{opcode = "pread", data = 42, fildes = fd, buf = abuf, nbytes = 4096, offset = 0, resfd = efd}}
    local ret = assert(S.io_submit(ctx, a))
    assert_equal(ret, 1, "expect one event submitted")
    local r = assert(ep:epoll_wait())
    assert_equal(#r, 1, "one event now")
    assert(r[1].IN, "read event")
    assert(r[1].fd == efd:getfd(), "expect to get fd of eventfd file back")
    local e = util.eventfd_read(efd)
    assert_equal(e, 1, "expect to be told one aio event ready")
    local r = assert(S.io_getevents(ctx, 1, 1))
    assert_equal(#r, 1, "expect one aio event")
    assert_equal(r[1].data, 42, "expect to get our data back")
    assert_equal(r[1].res, 4096, "expect to get full read")
    assert(efd:close())
    assert(ep:close())
    assert(S.io_destroy(ctx))
    assert(fd:close())
    assert(S.munmap(abuf, 4096))
  end,
}

test_processes = {
  test_nice = function()
    local n = assert(S.getpriority("process"))
    assert_equal(n, 0, "process should start at priority 0")
    local nn = assert(S.nice(1))
    assert_equal(nn, 1)
    local nn = assert(S.setpriority("process", 0, 1)) -- sets to 1, which it already is
  end,
  test_fork = function() -- TODO split up
    local pid0 = S.getpid()
    assert(pid0 > 1, "expecting my pid to be larger than 1")
    assert(S.getppid() > 1, "expecting my parent pid to be larger than 1")
    local pid = assert(S.fork())
    if pid == 0 then -- child
      fork_assert(S.getppid() == pid0, "parent pid should be previous pid")
      S.exit(23)
    else -- parent
      local w = assert(S.wait())
      assert(w.pid == pid, "expect fork to return same pid as wait")
      assert(w.WIFEXITED, "process should have exited normally")
      assert(w.EXITSTATUS == 23, "exit should be 23")
    end

    pid = assert(S.fork())
    if (pid == 0) then -- child
      fork_assert(S.getppid() == pid0, "parent pid should be previous pid")
      S.exit(23)
    else -- parent
      local w = assert(S.waitid("all", 0, "exited, stopped, continued"))
      assert_equal(w.signo, c.SIG.CHLD, "waitid to return SIGCHLD")
      assert_equal(w.status, 23, "exit should be 23")
      assert_equal(w.code, c.SIGCLD.EXITED, "normal exit expected")
    end

    pid = assert(S.fork())
    if (pid == 0) then -- child
      local script = [[
#!/bin/sh

[ $1 = "test" ] || (echo "shell assert $1"; exit 1)
[ $2 = "ing" ] || (echo "shell assert $2"; exit 1)
[ $PATH = "/bin:/usr/bin" ] || (echo "shell assert $PATH"; exit 1)

]]
      fork_assert(util.writefile(efile, script, "RWXU"))
      fork_assert(S.execve(efile, {efile, "test", "ing"}, {"PATH=/bin:/usr/bin"})) -- note first param of args overwritten
      -- never reach here
      os.exit()
    else -- parent
      local w = assert(S.waitpid(-1))
      assert(w.pid == pid, "expect fork to return same pid as wait")
      assert(w.WIFEXITED, "process should have exited normally")
      assert(w.EXITSTATUS == 0, "exit should be 0")
      assert(S.unlink(efile))
    end
  end,
  test_clone = function()
    local pid0 = S.getpid()
    local p = assert(S.clone()) -- no flags, should be much like fork.
    if p == 0 then -- child
      fork_assert(S.getppid() == pid0, "parent pid should be previous pid")
      S.exit(23)
    else -- parent
      local w = assert(S.waitpid(-1, "clone"))
      assert_equal(w.pid, p, "expect clone to return same pid as wait")
      assert(w.WIFEXITED, "process should have exited normally")
      assert(w.EXITSTATUS == 23, "exit should be 23")
    end
  end,
  test_setsid = function()
    -- need to fork twice in case start as process leader
    local pp1 = S.pipe()
    local pp2 = S.pipe()
    local pid = assert(S.fork())
    if (pid == 0) then -- child
      local pid = assert(S.fork())
      if (pid == 0) then -- child
        assert(pp1:read(nil, 1))
        local ok, err = S.setsid()
        ok = ok and ok == S.getpid() and ok == S.getsid()
        if ok then pp2:write("y") else pp2:write("n") end
        S._exit(0)
      else
        S._exit(0)
      end
    else
      local w = assert(S.waitid("pid", pid, "exited"))
      assert(pp1:write("a"))
      local ok = pp2:read(nil, 1)
      assert_equal(ok, "y")
      pp1:close()
      pp2:close()
    end
  end,
  test_setpgid = function()
    S.setpgid()
    assert_equal(S.getpgid(), S.getpid())
    assert_equal(S.getpgrp(), S.getpid())
  end,
}

test_ids_linux = {
  test_setreuid = function()
    assert(S.setreuid(S.geteuid(), S.getuid()))
  end,
  test_setregid = function()
    assert(S.setregid(S.getegid(), S.getgid()))
  end,
  test_getresuid = function()
    local u = assert(S.getresuid())
    assert_equal(u.ruid, S.getuid(), "real uid same")
    assert_equal(u.euid, S.geteuid(), "effective uid same")
  end,
  test_getresgid = function()
    local g = assert(S.getresgid())
    assert_equal(g.rgid, S.getgid(), "real gid same")
    assert_equal(g.egid, S.getegid(), "effective gid same")
  end,
  test_setresuid = function()
    local u = assert(S.getresuid())
    assert(S.setresuid(u))
  end,
  test_resuid_root = function()
    local u = assert(S.getresuid())
    assert(S.setresuid(0, 33, 44))
    local uu = assert(S.getresuid())
    assert_equal(uu.ruid, 0, "real uid as set")
    assert_equal(uu.euid, 33, "effective uid as set")
    assert_equal(uu.suid, 44, "saved uid as set")
    assert(S.setresuid(u))
  end,
  test_setresgid = function()
    local g = assert(S.getresgid())
    assert(S.setresgid(g))
  end,
  test_resgid_root = function()
    local g = assert(S.getresgid())
    assert(S.setresgid(0, 33, 44))
    local gg = assert(S.getresgid())
    assert_equal(gg.rgid, 0, "real gid as set")
    assert_equal(gg.egid, 33, "effective gid as set")
    assert_equal(gg.sgid, 44, "saved gid as set")
    assert(S.setresgid(g))
  end,
}

test_namespaces_root = {
  test_netns = function()
    local p = assert(S.clone("newnet"))
    if p == 0 then
      local i = fork_assert(nl.interfaces())
      fork_assert(i.lo and not i.lo.flags.up, "expect new network ns only has down lo interface")
      S.exit()
    else
      assert(S.waitpid(-1, "clone"))
    end
  end,
  test_netns_unshare = function()
    local p = assert(S.clone())
    if p == 0 then
      local ok = fork_assert(S.unshare("newnet"))
      local i = fork_assert(nl.interfaces())
      fork_assert(i.lo and not i.lo.flags.up, "expect new network ns only has down lo interface")
      S.exit()
    else
      assert(S.waitpid(-1, "clone"))
    end
  end,
  test_pidns = function()
    local p = assert(S.clone("newpid"))
    if p == 0 then
      fork_assert(S.getpid() == 1, "expec our pid to be 1 new new process namespace")
      S.exit()
    else
      assert(S.waitpid(-1, "clone"))
    end
  end,
  test_setns = function()
    local fd = assert(S.open("/proc/self/ns/net"))
    assert(fd:setns("newnet"))
    assert(fd:close())
  end,
  test_setns_fail = function()
    local fd = assert(S.open("/proc/self/ns/net"))
    assert(not fd:setns("newipc"))
    assert(fd:close())
  end,
}

test_filesystem = {
  test_statfs = function()
    local st = assert(S.statfs("."))
    assert(st.f_bfree < st.f_blocks, "expect less free space than blocks")
  end,
  test_fstatfs = function()
    local fd = assert(S.open(".", "rdonly"))
    local st = assert(S.fstatfs(fd))
    assert(st.f_bfree < st.f_blocks, "expect less free space than blocks")
    assert(fd:close())
  end,
  test_futimens = function()
    local fd = assert(S.creat(tmpfile, "RWXU"))
    assert(fd:futimens())
    local st1 = fd:stat()
    assert(fd:futimens{"omit", "omit"})
    local st2 = fd:stat()
    assert(st1.atime == st2.atime and st1.mtime == st2.mtime, "atime and mtime unchanged")
    assert(S.unlink(tmpfile))
    assert(fd:close())
  end,
  test_utimensat = function()
    local fd = assert(S.creat(tmpfile, "RWXU"))
    local dfd = assert(S.open("."))
    assert(S.utimensat(nil, tmpfile))
    local st1 = fd:stat()
    assert(S.utimensat(dfd, tmpfile, {"omit", "omit"}))
    local st2 = fd:stat()
    assert(st1.atime == st2.atime and st1.mtime == st2.mtime, "atime and mtime unchanged")
    assert(S.unlink(tmpfile))
    assert(fd:close())
    assert(dfd:close())
  end,
  test_utime = function()
    local fd = assert(S.creat(tmpfile, "RWXU"))
    local st1 = fd:stat()
    assert(S.utime(tmpfile, 100, 200))
    local st2 = fd:stat()
    assert(st1.atime ~= st2.atime and st1.mtime ~= st2.mtime, "atime and mtime changed")
    assert(st2.atime == 100 and st2.mtime == 200, "times as set")
    assert(S.unlink(tmpfile))
    assert(fd:close())
  end,
}

test_mount_linux_root = {
  test_mount = function()
    assert(S.mkdir(tmpfile))
    assert(S.mount("none", tmpfile, "tmpfs", "rdonly, noatime"))
    assert(S.umount(tmpfile))
    assert(S.rmdir(tmpfile))
  end,
  test_mount_table = function()
    assert(S.mkdir(tmpfile))
    assert(S.mount{source = "none", target = tmpfile, type = "tmpfs", flags = "rdonly, noatime"})
    assert(S.umount(tmpfile))
    assert(S.rmdir(tmpfile))
  end,
}

test_misc_root = {
  test_acct = function()
    S.acct() -- may not be configured
  end,
  test_sethostname = function()
    local h = S.gethostname()
    local hh = "testhostname"
    assert(S.sethostname(hh))
    assert_equal(hh, assert(S.gethostname()))
    assert(S.sethostname(h))
    assert_equal(h, assert(S.gethostname()))
  end,
  test_chroot = function()
    assert(S.chroot("/"))
  end,
  test_pivot_root = function()
    assert(S.mkdir(tmpfile3))
    local p = assert(S.clone("newns"))
    if p == 0 then
      fork_assert(S.mount(tmpfile3, tmpfile3, "none", "bind")) -- to make sure on different mount point
      fork_assert(S.mount(tmpfile3, tmpfile3, nil, "private"))
      fork_assert(S.chdir(tmpfile3))
      fork_assert(S.mkdir("old"))
      fork_assert(S.pivot_root(".", "old"))
      fork_assert(S.chdir("/"))
      local d = fork_assert(S.dirfile("/"))
      fork_assert(d["old"])
      --fork_assert(S.umount("old")) -- returning busy, TODO need to sort out why.
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
    assert(S.rmdir(tmpfile3 .. "/old")) -- until we can unmount above
    assert(S.rmdir(tmpfile3))
  end,
  test_reboot = function()
    local p = assert(S.clone("newpid"))
    if p == 0 then
      fork_assert(S.reboot("restart")) -- will send SIGHUP to us as in pid namespace NB older kernels may reboot! if so disable test
      S.pause()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.IFSIGNALED, "expect signal killed process")
    end
  end,
}

test_util = {
  test_rm_recursive = function()
    assert(S.mkdir(tmpfile, "rwxu"))
    assert(S.mkdir(tmpfile .. "/subdir", "rwxu"))
    assert(util.touch(tmpfile .. "/file"))
    assert(util.touch(tmpfile .. "/subdir/subfile"))
    assert(S.stat(tmpfile), "directory should be there")
    assert(S.stat(tmpfile).isdir, "should be a directory")
    local ok, err = S.rmdir(tmpfile)
    assert(not ok and err.notempty, "should fail as not empty")
    assert(util.rm(tmpfile)) -- rm -r
    assert(not S.stat(tmpfile), "directory should be deleted")
  end,
  test_rm_broken_symlink = function()
    assert(S.mkdir(tmpfile, "rwxu"))
    assert(S.symlink(tmpfile .. "/none", tmpfile .. "/link"))
    assert(util.rm(tmpfile))
    assert(not S.stat(tmpfile), "directory should be deleted")
  end,
  test_ls = function()
    assert(S.mkdir(tmpfile, "rwxu"))
    assert(util.touch(tmpfile .. "/file"))
    local list = assert(util.ls(tmpfile, true))
    assert_equal(#list, 1, "one item in directory")
    assert_equal(list[1], "file", "one file called file")
    assert(util.rm(tmpfile))
  end,
  test_ps = function()
    local ps = util.ps()
    local me = S.getpid()
    local found = false
    for i = 1, #ps do
      if ps[i].pid == 1 then
        assert(ps[i].cmdline:find("init") or ps[i].cmdline:find("systemd"), "expect init or systemd to be process 1 usually")
      end
      if ps[i].pid == me then found = true end
    end
    assert(found, "expect to find my process in ps")
    assert(tostring(ps), "can convert ps to string")
  end,
  test_bridge = function()
    local ok, err = util.bridge_add("br0")
    assert(ok or err.NOPKG or err.PERM, err) -- ok not to to have bridge in kernel, may not be root
    if ok then
      local i = assert(nl.interfaces())
      assert(i.br0)
      local b = assert(util.bridge_list())
      assert(b.br0 and b.br0.bridge.root_id, "expect to find bridge in list")
      assert(util.bridge_del("br0"))
      i = assert(nl.interfaces())
      assert(not i.br0, "bridge should be gone")
    end
  end,
  test_bridge_delete_fail = function()
    local ok, err = util.bridge_del("nosuchbridge99")
    assert(not ok and (err.NOPKG or err.PERM or err.NXIO), err)
  end,
  test_touch = function()
    assert(util.touch(tmpfile))
    assert(S.unlink(tmpfile))
  end,
  test_sendcred = function()
    local sv = assert(S.socketpair("unix", "stream"))
    assert(sv[2]:setsockopt("socket", "passcred", true)) -- enable receive creds
    local so = assert(sv[2]:getsockopt(c.SOL.SOCKET, c.SO.PASSCRED))
    assert(so == 1, "getsockopt should have updated value")
    assert(sv[1]:sendmsg()) -- sends single byte, which is enough to send credentials
    local r = assert(util.recvcmsg(sv[2]))
    assert(r.pid == S.getpid(), "expect to get my pid from sending credentials")
    assert(sv:close())
  end,
  test_sendfd = function()
    local sv = assert(S.socketpair("unix", "stream"))
    assert(util.sendfds(sv[1], S.stdin))
    local r = assert(util.recvcmsg(sv[2]))
    assert(#r.fd == 1, "expect to get one file descriptor back")
    assert(r.fd[1]:close())
    assert(sv:close())
  end,
  test_proc_self = function()
    local p = assert(util.proc())
    assert(not p.wrongname, "test non existent files")
    assert(p.cmdline and #p.cmdline > 1, "expect cmdline to exist")
    assert(p.exe and #p.exe > 1, "expect an executable")
    assert_equal(p.root, "/", "expect our root to be / usually")
  end,
  test_proc_init = function()
    local p = util.proc(1)
    assert(p and p.cmdline, "expect init to have cmdline")
    assert(p.cmdline:find("init") or p.cmdline:find("systemd"), "expect init or systemd to be process 1 usually")
  end,
  test_mounts_root = function()
    local cwd = assert(S.getcwd())
    local dir = cwd .. "/" .. tmpfile
    assert(S.mkdir(dir))
    local a = {source = "none", target = dir, type = "tmpfs", flags = "rdonly, noatime"}
    assert(S.mount(a))
    local m = assert(util.mounts())
    assert(#m > 0, "expect at least one mount point")
    local b = m[#m]
    assert_equal(b.source, a.source, "expect source match")
    assert_equal(b.target, a.target, "expect target match")
    assert_equal(b.type, a.type, "expect type match")
    assert_equal(c.MS[b.flags], c.MS[a.flags], "expect flags match")
    assert_equal(b.freq, "0")
    assert_equal(b.passno, "0")
    assert(S.umount(dir))
    assert(S.rmdir(dir))
  end,
  test_readfile_writefile = function()
    assert(util.writefile(tmpfile, teststring, "RWXU"))
    local ss = assert(util.readfile(tmpfile))
    assert_equal(ss, teststring, "readfile should get back what writefile wrote")
    assert(S.unlink(tmpfile))
  end,
  test_mapfile = function()
    assert(util.writefile(tmpfile, teststring, "RWXU"))
    local ss = assert(util.mapfile(tmpfile))
    assert_equal(ss, teststring, "mapfile should get back what writefile wrote")
    assert(S.unlink(tmpfile))
  end,
  test_cp = function()
    assert(util.writefile(tmpfile, teststring, "rusr,wusr"))
    assert(util.cp(tmpfile, tmpfile2, "rusr,wusr"))
    assert_equal(assert(util.mapfile(tmpfile2)), teststring)
    assert(S.unlink(tmpfile))
    assert(S.unlink(tmpfile2))
  end,
}

test_bpf = {
  test_bpf_struct_stmt = function()
    local bpf = t.sock_filter("LD,H,ABS", 12)
    assert_equal(bpf.code, c.BPF.LD + c.BPF.H + c.BPF.ABS)
    assert_equal(bpf.jt, 0)
    assert_equal(bpf.jf, 0)
    assert_equal(bpf.k, 12)
  end,
  test_bpf_struct_jump = function()
    local bpf = t.sock_filter("JMP,JEQ,K", c.ETHERTYPE.REVARP, 0, 3)
    assert_equal(bpf.code, c.BPF.JMP + c.BPF.JEQ + c.BPF.K)
    assert_equal(bpf.jt, 0)
    assert_equal(bpf.jf, 3)
    assert_equal(bpf.k, c.ETHERTYPE.REVARP)
  end,
}

test_seccomp = {
  test_no_new_privs = function() -- this must be done for non root to call type 2 seccomp
    local p = assert(S.clone())
     if p == 0 then
      local ok, err = S.prctl("set_no_new_privs", true)
      if err and err.INVAL then S.exit() end -- may not be supported
      local nnp = fork_assert(S.prctl("get_no_new_privs"))
      fork_assert(nnp == true)
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
  end,
  test_seccomp_allow = function()
    local p = assert(S.clone())
     if p == 0 then
      local ok, err = S.prctl("set_no_new_privs", true)
      if err and err.INVAL then S.exit() end -- may not be supported
      local nnp = fork_assert(S.prctl("get_no_new_privs"))
      fork_assert(nnp == true)
      local program = {
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
      }
      local pp = t.sock_filters(#program, program)
      local p = t.sock_fprog1{{#program, pp}}
      fork_assert(S.prctl("set_seccomp", "filter", p))
      local pid = S.getpid()
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
  end,
  test_seccomp = function()
    local p = assert(S.clone())
     if p == 0 then
      local ok, err = S.prctl("set_no_new_privs", true)
      if err and err.INVAL then S.exit() end -- may not be supported
      local nnp = fork_assert(S.prctl("get_no_new_privs"))
      fork_assert(nnp == true)
      local program = {
        -- test architecture correct
        t.sock_filter("LD,W,ABS", ffi.offsetof(t.seccomp_data, "arch")),
        t.sock_filter("JMP,JEQ,K", util.auditarch(), 1, 0),
        t.sock_filter("RET,K", c.SECCOMP_RET.KILL),
        -- get syscall number
        t.sock_filter("LD,W,ABS", ffi.offsetof(t.seccomp_data, "nr")),
        -- allow syscall getpid
        t.sock_filter("JMP,JEQ,K", c.SYS.getpid, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall exit_group
        t.sock_filter("JMP,JEQ,K", c.SYS.exit_group, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall mprotect in case luajit allocates memory for jitting
        t.sock_filter("JMP,JEQ,K", c.SYS.mprotect, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall mmap/mmap2 in case luajit allocates memory
        t.sock_filter("JMP,JEQ,K", c.SYS.mmap2 or c.SYS.mmap, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall brk in case luajit allocates memory
        t.sock_filter("JMP,JEQ,K", c.SYS.brk, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- else kill
        t.sock_filter("RET,K", c.SECCOMP_RET.KILL),
      }
      local pp = t.sock_filters(#program, program)
      local p = t.sock_fprog1{{#program, pp}}
      fork_assert(S.prctl("set_seccomp", "filter", p))
      local pid = S.getpid()
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      if w.EXITSTATUS ~= 0 then -- failed, get debug info
        assert_equal(w.code , c.SYS.seccomp, "expect reason is seccomp")
      end
      assert(w.EXITSTATUS == 0, "expect normal exit in clone")
    end
  end,
  test_seccomp_fail = function()
    local p = assert(S.clone())
     if p == 0 then
      local ok, err = S.prctl("set_no_new_privs", true)
      if err and err.INVAL then S.exit(42) end -- may not be supported
      local nnp = fork_assert(S.prctl("get_no_new_privs"))
      fork_assert(nnp == true)
      local program = {
        -- test architecture correct
        t.sock_filter("LD,W,ABS", ffi.offsetof(t.seccomp_data, "arch")),
        t.sock_filter("JMP,JEQ,K", util.auditarch(), 1, 0),
        t.sock_filter("RET,K", c.SECCOMP_RET.KILL),
        -- get syscall number
        t.sock_filter("LD,W,ABS", ffi.offsetof(t.seccomp_data, "nr")),
        -- allow syscall getpid
        t.sock_filter("JMP,JEQ,K", c.SYS.getpid, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall exit_group
        t.sock_filter("JMP,JEQ,K", c.SYS.exit_group, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- else kill
        t.sock_filter("RET,K", c.SECCOMP_RET.KILL),
      }
      local pp = t.sock_filters(#program, program)
      local p = t.sock_fprog1{{#program, pp}}
      fork_assert(S.prctl("set_seccomp", "filter", p))
      local pid = S.getpid()
      local fd = fork_assert(S.open("/dev/null", "rdonly")) -- not allowed
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 42 or w.TERMSIG == c.SIG.SYS, "expect SIGSYS from failed seccomp (or not implemented)")
    end
  end,
  test_seccomp_fail_errno = function()
    local p = assert(S.clone())
     if p == 0 then
      local ok, err = S.prctl("set_no_new_privs", true)
      if err and err.INVAL then S.exit(42) end -- may not be supported TODO change to feature test
      local nnp = fork_assert(S.prctl("get_no_new_privs"))
      fork_assert(nnp == true)
      local program = {
        -- test architecture correct
        t.sock_filter("LD,W,ABS", ffi.offsetof(t.seccomp_data, "arch")),
        t.sock_filter("JMP,JEQ,K", util.auditarch(), 1, 0),
        t.sock_filter("RET,K", c.SECCOMP_RET.KILL),
        -- get syscall number
        t.sock_filter("LD,W,ABS", ffi.offsetof(t.seccomp_data, "nr")),
        -- allow syscall getpid
        t.sock_filter("JMP,JEQ,K", c.SYS.getpid, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall write
        t.sock_filter("JMP,JEQ,K", c.SYS.write, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall exit_group
        t.sock_filter("JMP,JEQ,K", c.SYS.exit_group, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall mprotect in case luajit allocates memory for jitting
        t.sock_filter("JMP,JEQ,K", c.SYS.mprotect, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall mmap/mmap2 in case luajit allocates memory
        t.sock_filter("JMP,JEQ,K", c.SYS.mmap2 or c.SYS.mmap, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- allow syscall brk in case luajit allocates memory
        t.sock_filter("JMP,JEQ,K", c.SYS.brk, 0, 1),
        t.sock_filter("RET,K", c.SECCOMP_RET.ALLOW),
        -- else error exit, also return syscall number
        t.sock_filter("ALU,OR,K", c.SECCOMP_RET.ERRNO),
        t.sock_filter("RET,A"),
      }
      local pp = t.sock_filters(#program, program)
      local p = t.sock_fprog1{{#program, pp}}
      fork_assert(S.prctl("set_seccomp", "filter", p))
      local pid = S.getpid()
      local ofd, err = S.open("/dev/null", "rdonly") -- not allowed
      fork_assert(not ofd, "should not run open")
      fork_assert(err.errno == c.SYS.open, "syscall that did not work should be open")
      local pid = S.getpid()
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0 or w.EXITSTATUS == 42, "expect normal exit if supported")
    end
  end,
}

test_swap = {
  test_swap_constants = function()
    assert_equal(c.SWAP_FLAG["23, discard"], c.SWAP_FLAG["prefer, discard"] + bit.lshift(23, c.SWAP_FLAG["prio_shift"]))
  end,
  test_swap_fail = function()
    local ex = "PERM" -- EPERM if not root
    if S.geteuid() == 0 then ex = "INVAL" end
    local ok, err = S.swapon("/dev/null", "23, discard")
    assert(not ok and err[ex], "should not create swap on /dev/null")
    local ok, err = S.swapoff("/dev/null")
    assert(not ok and err[ex], "no swap on /dev/null")
  end,
  -- TODO need mkswap to test success
}

test_tuntap = {
  test_tuntap_root = function()
    local clonedev = "/dev/net/tun"
    local fd = assert(S.open(clonedev, "rdwr"))
    local ifr = t.ifreq()
    ifr.flags = "tun"
    assert(fd:ioctl("TUNSETIFF", ifr))
    assert_equal(ifr.name, "tun0")
    assert(fd:close())
    local i = assert(nl.interfaces())
    assert(not i.tun0, "interface should not persist")
  end,
}

test_capabilities = {
  test_cap_types = function()
    local cap = t.capabilities()
    assert_equal(cap.version, c.LINUX_CAPABILITY_VERSION[3], "expect defaults to version 3")
    for k, _ in pairs(c.CAP) do
      assert(not cap.effective[k])
    end
    for k, _ in pairs(c.CAP) do
      cap.effective[k] = true
    end
    for k, _ in pairs(c.CAP) do
      assert(cap.effective[k])
    end
    for k, _ in pairs(c.CAP) do
      cap.effective[k] = false
    end
    for k, _ in pairs(c.CAP) do
      assert(not cap.effective[k])
    end
  end,
  test_get_cap_version = function()
    local hdr = t.user_cap_header()
    S.capget(hdr) -- man page says returns error, but does not seem to
    assert_equal(hdr.version, c.LINUX_CAPABILITY_VERSION[3], "expect capability version 3 API on recent kernel")
  end,
  test_capget = function()
    local cap = S.capget()
    local count = 0
    for k, _ in pairs(c.CAP) do if cap.effective[k] then count = count + 1 end end
    if S.geteuid() == 0 then assert(count > 0, "root should have some caps") else assert(count == 0, "non-root has no caps") end
  end,
  test_capset_root = function()
    local p = assert(S.clone())
    if p == 0 then
      local cap = fork_assert(S.capget())
      cap.effective.sys_chroot = false
      fork_assert(S.capset(cap))
      local ok, err = S.chroot(".")
      fork_assert(not ok and err.PERM, "should not have chroot capability")
      S.exit()
    else
      local w = assert(S.waitpid(-1, "clone"))
      assert(w.EXITSTATUS == 0, "expect normal exit")
    end
  end,
  test_filesystem_caps_get = function()
    assert(util.touch(tmpfile))
    local c, err = util.capget(tmpfile)
    assert(not c and err.NODATA, "expect no caps")
    assert(S.unlink(tmpfile))
  end,
  test_filesystem_caps_getset_root = function()
    assert(util.touch(tmpfile))
    local cap, err = util.capget(tmpfile)
    assert(not cap and err.NODATA, "expect no caps")
    assert(util.capset(tmpfile, {permitted = "sys_chroot, sys_admin", inheritable = "chown, mknod"}, "create"))
    local cap = assert(util.capget(tmpfile))
    assert(cap.permitted.sys_chroot and cap.permitted.sys_admin, "expect capabilities set")
    assert(cap.inheritable.chown and cap.inheritable.mknod, "expect capabilities set")
    assert(S.unlink(tmpfile))
  end,
}

test_scheduler = {
  test_getcpu = function()
    local r, err = S.getcpu()
    assert((err and err.NOSYS) or type(r) == "table", "table returned if supported")
  end,
  test_sched_set_getscheduler = function()
    assert(S.sched_setscheduler(0, "normal"))
    local sched = assert(S.sched_getscheduler())
    assert_equal(sched, c.SCHED.NORMAL)
  end,
  test_sched_set_getscheduler_root = function()
    assert(S.sched_setscheduler(0, "idle"))
    local sched = assert(S.sched_getscheduler())
    assert_equal(sched, c.SCHED.IDLE)
    assert(S.sched_setscheduler(0, "normal"))
  end,
  test_sched_yield = function()
    assert(S.sched_yield())
  end,
  test_cpu_set = function()
    local set = t.cpu_set{0, 1}
    assert_equal(set.val[0], 3)
    assert(set:get(0) and set:get(1) and not set:get(2))
    assert(set[0] and set[1] and not set[2])
  end,
  test_sched_getaffinity = function()
    local set = S.sched_getaffinity()
    assert(set[0], "should be able to run on cpu 0")
  end,
  test_sched_setaffinity = function()
    local set = S.sched_getaffinity()
    set[1] = false
    assert(not set[1])
    assert(S.sched_setaffinity(0, set))
  end,
  test_get_sched_priority_minmax = function()
    local min = S.sched_get_priority_min("fifo")
    local max = S.sched_get_priority_max("fifo")
    assert_equal(min, 1) -- values for Linux
    assert_equal(max, 99) -- values for Linux
  end,
  test_sched_getparam = function()
    local prio = S.sched_getparam()
    assert_equal(prio, 0, "standard schedular has no priority value")
  end,
    test_sched_setgetparam_root = function()
    assert(S.sched_setscheduler(0, "fifo", 1))
    assert_equal(S.sched_getscheduler(), c.SCHED.FIFO)
    local prio = S.sched_getparam()
    assert_equal(prio, 1, "set to 1")
    S.sched_setparam(0, 50)
    local prio = S.sched_getparam()
    assert_equal(prio, 50, "set to 50")
    assert(S.sched_setscheduler(0, "normal"))
  end,
  test_sched_rr_get_interval = function()
    local ts = assert(S.sched_rr_get_interval())
  end,
}

test_mq = {
  test_mq_open_close_unlink = function()
    local mq = assert(S.mq_open(mqname, "rdwr,creat", "rusr,wusr", {maxmsg = 10, msgsize = 512}))
    assert(S.mq_unlink(mqname)) -- unlink so errors do not leave dangling
    assert(mq:close())
  end,
  test_mq_getsetattr = function()
    local mq = assert(S.mq_open(mqname, "rdwr,creat, nonblock", "rusr,wusr", {maxmsg = 10, msgsize = 512}))
    assert(S.mq_unlink(mqname))
    local attr = mq:getattr()
    assert_equal(attr.flags, c.O.NONBLOCK)
    assert_equal(attr.maxmsg, 10)
    assert_equal(attr.msgsize, 512)
    assert(mq:setattr(0)) -- clear nonblock flag
    local attr = mq:getattr()
    assert_equal(attr.flags, 0)
    assert(mq:close())
  end,
  test_mq_send_receive = function()
    local mq = assert(S.mq_open(mqname, "rdwr,creat", "rusr,wusr", {maxmsg = 10, msgsize = 1}))
    assert(S.mq_unlink(mqname))
    assert(mq:timedsend("a"))  -- default prio is zero so should be behind second message
    assert(mq:send("b", nil, 10, 1)) -- 1 is timeout in seconds
    local prio = t.int1(-1) -- initialise with invalid value
    local msg = mq:timedreceive(nil, 1, prio, 1)
    assert_equal(msg, "b")
    assert_equal(prio[0], 10)
    local msg = mq:receive(nil, 1)
    assert_equal(msg, "a")
    assert(mq:close())    
  end,
  -- TODO mq_notify
}

test_shm = {
  test_shm = function()
    local name = "XXXXXYYYY" .. S.getpid()
    local fd, err = S.shm_open(name, "rdwr, creat")
    if not fd and err.ACCES then return end -- Travis CI does not have mounted...
    assert(fd, err)
    assert(S.shm_unlink(name))
    assert(fd:truncate(4096))
    assert(fd:close())
  end,
}

