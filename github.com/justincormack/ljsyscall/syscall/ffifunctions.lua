-- choose correct ffi functions for OS

-- TODO many are common and can be shared here

local abi = require "syscall.abi"

require("syscall." .. abi.os .. ".ffifunctions")

local cdef = require "ffi".cdef

-- common functions for BSD, oSX and and Linux

cdef[[
int open(const char *pathname, int flags, mode_t mode);
int close(int fd);
int chdir(const char *path);
int fchdir(int fd);
int mkdir(const char *pathname, mode_t mode);
int rmdir(const char *pathname);
int unlink(const char *pathname);
int rename(const char *oldpath, const char *newpath);
int chmod(const char *path, mode_t mode);
int fchmod(int fd, mode_t mode);
int chown(const char *path, uid_t owner, gid_t group);
int fchown(int fd, uid_t owner, gid_t group);
int lchown(const char *path, uid_t owner, gid_t group);
int link(const char *oldpath, const char *newpath);
int linkat(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, int flags);
int symlink(const char *oldpath, const char *newpath);
int chroot(const char *path);
mode_t umask(mode_t mask);
void sync(void);
int mknod(const char *pathname, mode_t mode, dev_t dev);
int mkfifo(const char *path, mode_t mode);
ssize_t read(int fd, void *buf, size_t count);
ssize_t readv(int fd, const struct iovec *iov, int iovcnt);
ssize_t write(int fd, const void *buf, size_t count);
ssize_t writev(int fd, const struct iovec *iov, int iovcnt);
ssize_t pread(int fd, void *buf, size_t count, off_t offset);
ssize_t pwrite(int fd, const void *buf, size_t count, off_t offset);
ssize_t preadv(int fd, const struct iovec *iov, int iovcnt, off_t offset);
ssize_t pwritev(int fd, const struct iovec *iov, int iovcnt, off_t offset);
int access(const char *pathname, int mode);
off_t lseek(int fd, off_t offset, int whence);
ssize_t readlink(const char *path, char *buf, size_t bufsiz);
int fsync(int fd);
int fdatasync(int fd);
int fcntl(int fd, int cmd, void *arg); /* arg is long or pointer */
int stat(const char *path, struct stat *sb);
int lstat(const char *path, struct stat *sb);
int fstat(int fd, struct stat *sb);
int truncate(const char *path, off_t length);
int ftruncate(int fd, off_t length);
int shm_open(const char *pathname, int flags, mode_t mode);
int shm_unlink(const char *name);

int socket(int domain, int type, int protocol);
int socketpair(int domain, int type, int protocol, int sv[2]);
int dup(int oldfd);
int dup2(int oldfd, int newfd);
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
// for sendto and recvfrom use void pointer not const struct sockaddr * to avoid casting TODO should cast
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const void *dest_addr, socklen_t addrlen);
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags, void *src_addr, socklen_t *addrlen);
ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags);
ssize_t recvmsg(int sockfd, struct msghdr *msg, int flags);
int getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen);
int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen);
int bind(int sockfd, const void *addr, socklen_t addrlen); // void not struct
int listen(int sockfd, int backlog);
int connect(int sockfd, const void *addr, socklen_t addrlen);
int accept(int sockfd, void *addr, socklen_t *addrlen);
int getsockname(int sockfd, void *addr, socklen_t *addrlen);
int getpeername(int sockfd, void *addr, socklen_t *addrlen);
int shutdown(int sockfd, int how);
int pipe(int pipefd[2]);

uid_t getuid(void);
uid_t geteuid(void);
pid_t getpid(void);
pid_t getppid(void);
gid_t getgid(void);
gid_t getegid(void);
int setuid(uid_t uid);
int setgid(gid_t gid);
int seteuid(uid_t euid);
int setegid(gid_t egid);
pid_t getsid(pid_t pid);
pid_t setsid(void);
int setpgid(pid_t pid, pid_t pgid);
pid_t getpgid(pid_t pid);
pid_t getpgrp(void);

pid_t fork(void);
int execve(const char *filename, const char *argv[], const char *envp[]);
void _exit(int status);
int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact);
int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);
int sigpending(sigset_t *set);
int sigsuspend(const sigset_t *mask);
int kill(pid_t pid, int sig);

int getgroups(int size, gid_t list[]);
int setgroups(size_t size, const gid_t *list);

int gettimeofday(struct timeval *tv, void *tz);
int settimeofday(const struct timeval *tv, const void *tz);
int getitimer(int which, struct itimerval *curr_value);
int setitimer(int which, const struct itimerval *new_value, struct itimerval *old_value);

int acct(const char *filename);

/* TODO in NetBSD these are implemented with wait4, we may want to do this */
pid_t wait(int *status);
pid_t waitpid(pid_t pid, int *status, int options);
]]

