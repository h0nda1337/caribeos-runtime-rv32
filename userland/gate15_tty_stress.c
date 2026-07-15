/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#define GATE15_TTY_LINES 1000U
#define GATE15_TTY_BATCH 100U

static int
read_line(char *line, size_t capacity)
{
	for (;;) {
		ssize_t count = read(STDIN_FILENO, line, capacity - 1U);

		if (count > 0) {
			line[count] = '\0';
			return (int)count;
		}
		if (count < 0 && errno == EINTR) {
			continue;
		}
		return -1;
	}
}

int
main(int argc, char **argv)
{
	struct termios original;
	struct termios quiet;
	unsigned int line_index;
	char line[32];
	char expected[16];

	if (argc != 2 || strcmp(argv[1], "1000") != 0) {
		return 2;
	}
	if (tcgetattr(STDIN_FILENO, &original) != 0) {
		return 3;
	}
	quiet = original;
	quiet.c_lflag &= (tcflag_t)~ECHO;
	if (tcsetattr(STDIN_FILENO, TCSANOW, &quiet) != 0) {
		return 4;
	}
	printf("[process-gate-15] tty-ready lines=%u batch=%u\n",
	    GATE15_TTY_LINES, GATE15_TTY_BATCH);
	fflush(stdout);
	for (line_index = 0U; line_index < GATE15_TTY_LINES; line_index++) {
		int count = read_line(line, sizeof(line));
		int expected_count = snprintf(expected, sizeof(expected),
		    "L%04u\n", line_index);

		if (count != expected_count || strcmp(line, expected) != 0) {
			(void)tcsetattr(STDIN_FILENO, TCSANOW, &original);
			return 5;
		}
		if ((line_index + 1U) % GATE15_TTY_BATCH == 0U) {
			printf("[process-gate-15] tty-progress=%u\n",
			    line_index + 1U);
			fflush(stdout);
		}
	}
	if (tcsetattr(STDIN_FILENO, TCSANOW, &original) != 0) {
		return 6;
	}
	printf("[process-gate-15] tty-lines=1000 content=validated canonical-blocking PASS\n");
	return 0;
}
