/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/times.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

static int
fail(const char *operation)
{
    printf("[musl-probe] FAIL %s errno=%d (%s)\n", operation, errno,
        strerror(errno));
    return 1;
}

static int
handoff_dynamic_loader(void)
{
    char *next_argv[] = {
        (char *)"/usr/bin/dynamic-script",
        (char *)"--from-musl",
        NULL
    };
    int fd;

    fd = open("/usr/bin/dynamic-script", O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        return fail("open dynamic-script");
    }
    printf("[musl-probe] execveat AT_EMPTY_PATH -> shebang/ET_DYN loader\n");
    if (syscall(SYS_execveat, fd, "", next_argv, environ, AT_EMPTY_PATH) < 0) {
        return fail("execveat");
    }
    return 127;
}

int
main(int argc, char **argv)
{
    struct utsname uts;
    struct timespec ts;
    struct stat st;
    struct tms process_times;
    DIR *dir;
    struct dirent *entry;
    char cwd[128];
    char note[96];
    char *heap;
    const char *home;
    const char *path;
    int fd;
    int entries = 0;
    ssize_t count;
    clock_t ticks;
    char *bash_argv[] = {
        (char *)"/bin/bash",
        (char *)"/usr/lib/bash-smoke.sh",
        NULL
    };

    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc > 1 && strcmp(argv[1], "--after-bash") == 0) {
        printf("[musl-probe] resumed after GNU Bash 5.3.5\n");
        return handoff_dynamic_loader();
    }

    printf("[musl-probe] musl RV32 C runtime entered argc=%d argv0=%s\n",
        argc, argc > 0 ? argv[0] : "(null)");

    home = getenv("HOME");
    path = getenv("PATH");
    printf("[musl-probe] env HOME=%s PATH=%s\n",
        home != NULL ? home : "(null)", path != NULL ? path : "(null)");

    heap = malloc(256);
    if (heap == NULL) {
        return fail("malloc");
    }
    snprintf(heap, 256, "sizeof(void*)=%u pid=%ld uid=%ld tty=%d",
        (unsigned)sizeof(void *), (long)getpid(), (long)getuid(), isatty(1));
    printf("[musl-probe] libc heap/stdio %s\n", heap);
    free(heap);

    if (uname(&uts) != 0) {
        return fail("uname");
    }
    printf("[musl-probe] uname %s %s %s\n", uts.sysname, uts.release,
        uts.machine);

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return fail("clock_gettime");
    }
    ticks = times(&process_times);
    if (ticks == (clock_t)-1) {
        return fail("times");
    }
    printf("[musl-probe] time monotonic=%ld.%09ld ticks=%ld\n",
        (long)ts.tv_sec, ts.tv_nsec, (long)ticks);

    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        return fail("getcwd");
    }
    if (stat("/usr/lib/caribe.note", &st) != 0) {
        return fail("stat");
    }
    printf("[musl-probe] fs cwd=%s note-size=%ld mode=%o\n", cwd,
        (long)st.st_size, (unsigned)st.st_mode);

    fd = open("/usr/lib/caribe.note", O_RDONLY);
    if (fd < 0) {
        return fail("open");
    }
    count = read(fd, note, sizeof(note) - 1U);
    if (count < 0) {
        close(fd);
        return fail("read");
    }
    note[count] = '\0';
    if (close(fd) != 0) {
        return fail("close");
    }
    printf("[musl-probe] read %ld bytes prefix=%.24s\n", (long)count, note);

    dir = opendir("/usr/lib");
    if (dir == NULL) {
        return fail("opendir");
    }
    while ((entry = readdir(dir)) != NULL) {
        entries++;
    }
    if (closedir(dir) != 0) {
        return fail("closedir");
    }
    printf("[musl-probe] readdir /usr/lib entries=%d\n", entries);
    printf("[musl-probe] PASS real musl libc on XNU-CaribeOS RV32\n");

    printf("[musl-probe] exec /bin/bash /usr/lib/bash-smoke.sh\n");
    if (execve("/bin/bash", bash_argv, environ) < 0) {
        return fail("execve bash");
    }
    return 127;
}
