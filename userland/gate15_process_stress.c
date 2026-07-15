/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define GATE15_MAX_ROUNDS 1000U

static int
run_child(int do_exec)
{
	if (do_exec) {
		char *const argv[] = { "/bin/gate15-worker", NULL };
		char *const envp[] = { NULL };

		execve(argv[0], argv, envp);
		return 92;
	}
	return 0;
}

int
main(int argc, char **argv)
{
	char *end = NULL;
	unsigned long parsed;
	unsigned int round;
	int do_exec;

	if (argc != 3 ||
	    (strcmp(argv[1], "fork") != 0 && strcmp(argv[1], "exec") != 0)) {
		return 2;
	}
	do_exec = strcmp(argv[1], "exec") == 0;
	errno = 0;
	parsed = strtoul(argv[2], &end, 10);
	if (errno != 0 || end == argv[2] || *end != '\0' || parsed == 0U ||
	    parsed > GATE15_MAX_ROUNDS) {
		return 3;
	}

	for (round = 0U; round < (unsigned int)parsed; round++) {
		pid_t pid = fork();
		int status = 0;

		if (pid == 0) {
			_exit(run_child(do_exec));
		}
		if (pid < 0) {
			return 4;
		}
		while (waitpid(pid, &status, 0) < 0) {
			if (errno != EINTR) {
				return 5;
			}
		}
		if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
			return 6;
		}
	}

	printf("[process-gate-15] fork-%s-exit-wait rounds=%lu PASS\n",
	    do_exec ? "exec" : "only", parsed);
	return 0;
}
