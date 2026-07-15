/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define GATE15_SIGNAL_MAX_ROUNDS 1000U

static unsigned char alternate_stack[16384];
static volatile sig_atomic_t handler_count;
static volatile sig_atomic_t siginfo_count;
static volatile sig_atomic_t altstack_count;

static void
gate15_handler(int signal, siginfo_t *info, void *context)
{
	volatile unsigned char stack_marker = 0U;
	uintptr_t address = (uintptr_t)&stack_marker;

	(void)context;
	if (signal == SIGUSR1 && info != NULL && info->si_signo == SIGUSR1) {
		siginfo_count++;
	}
	if (address >= (uintptr_t)alternate_stack &&
	    address < (uintptr_t)alternate_stack + sizeof(alternate_stack)) {
		altstack_count++;
	}
	handler_count++;
}

int
main(int argc, char **argv)
{
	struct sigaction action;
	stack_t stack;
	char *end = NULL;
	unsigned long rounds;
	unsigned int round;

	if (argc != 2) {
		return 2;
	}
	errno = 0;
	rounds = strtoul(argv[1], &end, 10);
	if (errno != 0 || end == argv[1] || *end != '\0' || rounds == 0U ||
	    rounds > GATE15_SIGNAL_MAX_ROUNDS) {
		return 3;
	}
	memset(&stack, 0, sizeof(stack));
	stack.ss_sp = alternate_stack;
	stack.ss_size = sizeof(alternate_stack);
	if (sigaltstack(&stack, NULL) != 0) {
		return 4;
	}
	memset(&action, 0, sizeof(action));
	action.sa_sigaction = gate15_handler;
	action.sa_flags = SA_SIGINFO | SA_ONSTACK;
	sigemptyset(&action.sa_mask);
	if (sigaction(SIGUSR1, &action, NULL) != 0) {
		return 5;
	}
	for (round = 0U; round < (unsigned int)rounds; round++) {
		if (kill(getpid(), SIGUSR1) != 0 ||
		    handler_count != (sig_atomic_t)(round + 1U)) {
			return 6;
		}
	}
	if (siginfo_count != (sig_atomic_t)rounds ||
	    altstack_count != (sig_atomic_t)rounds) {
		return 7;
	}
	printf("[process-gate-15] signals=%lu handlers=%d siginfo=%d altstack=%d PASS\n",
	    rounds, (int)handler_count, (int)siginfo_count, (int)altstack_count);
	return 0;
}
