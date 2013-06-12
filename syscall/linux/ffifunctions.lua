-- define Linux system calls for ffi

local cdef = require "ffi".cdef

cdef[[
int openat(int dirfd, const char *pathname, int flags, mode_t mode);
int mkdirat(int dirfd, const char *pathname, mode_t mode);
int unlinkat(int dirfd, const char *pathname, int flags);
int renameat(int olddirfd, const char *oldpath, int newdirfd, const char *newpath);
int fchownat(int dirfd, const char *pathname, uid_t owner, gid_t group, int flags);
int symlinkat(const char *oldpath, int newdirfd, const char *newpath);
int mknodat(int dirfd, const char *pathname, mode_t mode, dev_t dev);

int uname(struct utsname *buf);
int sethostname(const char *name, size_t len);
int setdomainname(const char *name, size_t len);

int setreuid(uid_t ruid, uid_t euid);
int setregid(gid_t rgid, gid_t egid);
int getresuid(uid_t *ruid, uid_t *euid, uid_t *suid);
int getresgid(gid_t *rgid, gid_t *egid, gid_t *sgid);
int setresuid(uid_t ruid, uid_t euid, uid_t suid);
int setresgid(gid_t rgid, gid_t egid, gid_t sgid);

int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options);
void exit_group(int status);

time_t time(time_t *t);

int dup3(int oldfd, int newfd, int flags);

/* down to here have moved to shared calls */
int clock_getres(clockid_t clk_id, struct timespec *res);
int clock_gettime(clockid_t clk_id, struct timespec *tp);
int clock_settime(clockid_t clk_id, const struct timespec *tp);
int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *request, struct timespec *remain);
unsigned int alarm(unsigned int seconds);
int sysinfo(struct sysinfo *info);
int getpriority(int which, int who);
int setpriority(int which, int who, int prio);
int prctl(int option, unsigned long arg2, unsigned long arg3, unsigned long arg4, unsigned long arg5);
int signalfd(int fd, const sigset_t *mask, int flags);
int timerfd_create(int clockid, int flags);
int timerfd_settime(int fd, int flags, const struct itimerspec *new_value, struct itimerspec *old_value);
int timerfd_gettime(int fd, struct itimerspec *curr_value);

int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
int ppoll(struct pollfd *fds, nfds_t nfds, const struct timespec *timeout_ts, const sigset_t *sigmask);
int pselect(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timespec *timeout, const sigset_t *sigmask);
int readlinkat(int dirfd, const char *pathname, char *buf, size_t bufsiz);

int epoll_create1(int flags);
int epoll_create(int size);
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
int epoll_pwait(int epfd, struct epoll_event *events, int maxevents, int timeout, const sigset_t *sigmask);
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
int eventfd(unsigned int initval, int flags);
ssize_t splice(int fd_in, off_t *off_in, int fd_out, off_t *off_out, size_t len, unsigned int flags);
ssize_t vmsplice(int fd, const struct iovec *iov, unsigned long nr_segs, unsigned int flags);
ssize_t tee(int fd_in, int fd_out, size_t len, unsigned int flags);
int reboot(int cmd);
int klogctl(int type, char *bufp, int len);
int inotify_init1(int flags);
int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
int inotify_rm_watch(int fd, uint32_t wd);
int adjtimex(struct timex *buf);
int sync_file_range(int fd, off_t offset, off_t count, unsigned int flags);

int fchmodat(int dirfd, const char *pathname, mode_t mode, int flags);
int pause(void);
int prlimit64(pid_t pid, int resource, const struct rlimit64 *new_limit, struct rlimit64 *old_limit);

int accept4(int sockfd, void *addr, socklen_t *addrlen, int flags);

void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
void *mmap2(void *addr, size_t length, int prot, int flags, int fd, off32_t pgoffset);
int munmap(void *addr, size_t length);
int msync(void *addr, size_t length, int flags);
int mlock(const void *addr, size_t len);
int munlock(const void *addr, size_t len);
int mlockall(int flags);
int munlockall(void);
void *mremap(void *old_address, size_t old_size, size_t new_size, int flags, void *new_address);
int madvise(void *addr, size_t length, int advice);
int fallocate(int fd, int mode, off_t offset, off_t len); /* note there are 32 bit issues with glibc */
ssize_t readahead(int fd, off_t offset, size_t count);

int pipe2(int pipefd[2], int flags);
int mount(const char *source, const char *target, const char *filesystemtype, unsigned long mountflags, const void *data);
int umount(const char *target);
int umount2(const char *target, int flags);

int nanosleep(const struct timespec *req, struct timespec *rem);
int faccessat(int dirfd, const char *pathname, int mode, int flags);
int statfs(const char *path, struct statfs64 *buf);
int fstatfs(int fd, struct statfs64 *buf);
int futimens(int fd, const struct timespec times[2]);
int utimensat(int dirfd, const char *pathname, const struct timespec times[2], int flags);

ssize_t listxattr(const char *path, char *list, size_t size);
ssize_t llistxattr(const char *path, char *list, size_t size);
ssize_t flistxattr(int fd, char *list, size_t size);
ssize_t getxattr(const char *path, const char *name, void *value, size_t size);
ssize_t lgetxattr(const char *path, const char *name, void *value, size_t size);
ssize_t fgetxattr(int fd, const char *name, void *value, size_t size);
int setxattr(const char *path, const char *name, const void *value, size_t size, int flags);
int lsetxattr(const char *path, const char *name, const void *value, size_t size, int flags);
int fsetxattr(int fd, const char *name, const void *value, size_t size, int flags);
int removexattr(const char *path, const char *name);
int lremovexattr(const char *path, const char *name);
int fremovexattr(int fd, const char *name);

int unshare(int flags);
int setns(int fd, int nstype);
int pivot_root(const char *new_root, const char *put_old);
int swapon(const char *path, int swapflags);
int swapoff(const char *path);

int syscall(int number, ...);

int ioctl(int d, int request, void *argp); /* void* easiest here */

/* note we use underlying struct not typedefs here */
int capget(struct user_cap_header *hdrp, struct user_cap_data *datap);
int capset(struct user_cap_header *hdrp, const struct user_cap_data *datap);

/* getcpu not defined by glibc */
int getcpu(unsigned *cpu, unsigned *node, void *tcache);

int sched_setscheduler(pid_t pid, int policy, const struct sched_param *param);
int sched_getscheduler(pid_t pid);
int sched_yield(void);
int sched_get_priority_max(int policy);
int sched_get_priority_min(int policy);
int sched_setparam(pid_t pid, const struct sched_param *param);
int sched_getparam(pid_t pid, struct sched_param *param);
int sched_rr_get_interval(pid_t pid, struct timespec *tp);

/* TODO from here to libc functions are not implemented yet */
int tgkill(int tgid, int tid, int sig);
int brk(void *addr);
void *sbrk(intptr_t increment);

/* these need their types adding or fixing before can uncomment */
/*
caddr_t create_module(const char *name, size_t size);
int init_module(const char *name, struct module *image);
int get_kernel_syms(struct kernel_sym *table);
int getrusage(int who, struct rusage *usage);
int get_thread_area(struct user_desc *u_info);
long kexec_load(unsigned long entry, unsigned long nr_segments, struct kexec_segment *segments, unsigned long flags);
int lookup_dcookie(u64 cookie, char *buffer, size_t len);
int msgctl(int msqid, int cmd, struct msqid_ds *buf);
int msgget(key_t key, int msgflg);
long ptrace(enum __ptrace_request request, pid_t pid, void *addr, void *data);
int quotactl(int cmd, const char *special, int id, caddr_t addr);
int semget(key_t key, int nsems, int semflg);
int shmctl(int shmid, int cmd, struct shmid_ds *buf);
int shmget(key_t key, size_t size, int shmflg);
int timer_create(clockid_t clockid, struct sigevent *sevp, timer_t *timerid);
int timer_delete(timer_t timerid);
int timer_getoverrun(timer_t timerid);
int timer_settime(timer_t timerid, int flags, const struct itimerspec *new_value, struct itimerspec * old_value);
int timer_gettime(timer_t timerid, struct itimerspec *curr_value);
clock_t times(struct tms *buf);
int utime(const char *filename, const struct utimbuf *times);
*/
int msgsnd(int msqid, const void *msgp, size_t msgsz, int msgflg);
ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg);

int delete_module(const char *name);
int flock(int fd, int operation);
int get_mempolicy(int *mode, unsigned long *nodemask, unsigned long maxnode, unsigned long addr, unsigned long flags);
int mbind(void *addr, unsigned long len, int mode, unsigned long *nodemask, unsigned long maxnode, unsigned flags);
long migrate_pages(int pid, unsigned long maxnode, const unsigned long *old_nodes, const unsigned long *new_nodes);
int mincore(void *addr, size_t length, unsigned char *vec);
long move_pages(int pid, unsigned long count, void **pages, const int *nodes, int *status, int flags);
int mprotect(const void *addr, size_t len, int prot);
int personality(unsigned long persona);
int recvmmsg(int sockfd, struct mmsghdr *msgvec, unsigned int vlen, unsigned int flags, struct timespec *timeout);
int remap_file_pages(void *addr, size_t size, int prot, ssize_t pgoff, int flags);
int semctl(int semid, int semnum, int cmd, ...);
int semop(int semid, struct sembuf *sops, unsigned nsops);
int semtimedop(int semid, struct sembuf *sops, unsigned nsops, struct timespec *timeout);
void *shmat(int shmid, const void *shmaddr, int shmflg);
int shmdt(const void *shmaddr);
int swapon(const char *path, int swapflags);
int swapoff(const char *path);
void syncfs(int fd);
pid_t wait4(pid_t pid, int *status, int options, struct rusage *rusage);

pid_t gettid(void);
int setfsgid(uid_t fsgid);
int setfsuid(uid_t fsuid);
long keyctl(int cmd, ...);
]]

