/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>
extern char **environ;
int main(int argc, char **argv) {
    unsigned char *heap = malloc(128);
    unsigned char *mapping =
        mmap(NULL, 8192, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    unsigned int round, i;
    setvbuf(stdout, NULL, _IONBF, 0);
    if (!heap || mapping == MAP_FAILED)
        return 1;
    if (argc == 2 && !strcmp(argv[1], "--child")) {
        memset(heap, 0x11, 128);
        memset(mapping, 0x22, 8192);
        if (munmap(mapping, 8192))
            return 2;
        free(heap);
        return 0;
    }
    memset(heap, 0xa5, 128);
    memset(mapping, 0x5a, 8192);
    for (round = 0; round < 32; round++) {
        pid_t child = (pid_t)syscall(SYS_clone, SIGCHLD, 0, 0, 0, 0), waited;
        int status;
        if (child < 0)
            return 3;
        if (child == 0) {
            char *args[] = {"/bin/private-vm-probe", "--child", NULL};
            execve(args[0], args, environ);
            _exit(127);
        }
        do {
            waited = waitpid(child, &status, 0);
        } while (waited < 0 && errno == EINTR);
        if (waited != child || !WIFEXITED(status) || WEXITSTATUS(status))
            return 4;
        for (i = 0; i < 128; i++)
            if (heap[i] != 0xa5)
                return 5;
        for (i = 0; i < 8192; i++)
            if (mapping[i] != 0x5a)
                return 6;
    }
    if (munmap(mapping, 8192))
        return 7;
    for (round = 0; round < 256; round++) {
        unsigned char *p =
            mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (p == MAP_FAILED)
            return 8;
        for (i = 0; i < 4096; i++)
            if (p[i])
                return 9;
        memset(p, 0xcd, 4096);
        if (munmap(p, 4096))
            return 10;
    }
    free(heap);
    puts("[graphics-vm] private heap/mmap fork-exec isolation=32 recycling=256 PASS");
    return 0;
}
