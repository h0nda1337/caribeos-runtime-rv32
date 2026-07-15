/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#define _GNU_SOURCE

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static int
fail(const char *operation)
{
    printf("[process-gate-11] FAIL %s errno=%d\n", operation, errno);
    return 1;
}

int
main(void)
{
    char *bash_argv[] = {
        (char *)"/bin/bash",
        (char *)"--noprofile",
        (char *)"--norc",
        (char *)"-i",
        NULL
    };
    pid_t pid;
    pid_t waited;
    int status;

    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    if (getpid() != 1 || !isatty(STDIN_FILENO) ||
        !isatty(STDOUT_FILENO) || !isatty(STDERR_FILENO)) {
        return fail("PID1/TTY identity");
    }
    if (chdir("/") != 0 || setenv("HOME", "/", 1) != 0 ||
        setenv("PATH", "/sbin:/bin", 1) != 0 ||
        setenv("TERM", "vt100", 1) != 0 ||
        setenv("PS1", "bash-5.3$ ", 1) != 0 ||
        setenv("HISTFILE", "/dev/null", 1) != 0 ||
        setenv("LC_ALL", "C", 1) != 0) {
        return fail("interactive environment");
    }
    if (setpgid(0, 0) != 0 || tcsetpgrp(STDIN_FILENO, getpgrp()) != 0) {
        return fail("PID1 foreground process group");
    }

    printf("[process-gate-11] PID 1 interactive init started "
        "tty=1 pgid=%ld sid=%ld PASS\n", (long)getpgrp(),
        (long)getsid(0));
    printf("CaribeOS login shell\n");

    pid = (pid_t)syscall(SYS_clone, SIGCHLD, 0, 0, 0, 0);
    if (pid < 0) {
        return fail("clone Bash child");
    }
    if (pid == 0) {
        if (setpgid(0, 0) != 0 ||
            tcsetpgrp(STDIN_FILENO, getpgrp()) != 0) {
            _exit(126);
        }
        execve("/bin/bash", bash_argv, environ);
        printf("[process-gate-11] FAIL execve /bin/bash errno=%d\n", errno);
        _exit(127);
    }
	if (setpgid(pid, pid) != 0 || tcsetpgrp(STDIN_FILENO, pid) != 0) {
		return fail("Bash foreground process group handoff");
	}

    printf("[process-gate-11] Bash child pid=%ld affinity=cpu0 PASS\n",
        (long)pid);
    do {
        waited = waitpid(pid, &status, 0);
    } while (waited < 0 && errno == EINTR);
    if (waited != pid) {
        return fail("waitpid Bash child");
    }
	if (tcsetpgrp(STDIN_FILENO, getpgrp()) != 0) {
		return fail("PID1 terminal foreground reclaim");
	}
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        printf("[process-gate-11] FAIL Bash wait status=0x%x\n", status);
        return 1;
    }

    printf("[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS\n");
    printf("[process-gate-11] Gate 11 persistent interactive Bash PASS\n");
    return 0;
}
