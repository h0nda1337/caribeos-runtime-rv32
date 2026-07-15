/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define GATE15_PIPELINE_MAX_ROUNDS 100U
#define GATE15_PIPELINE_BYTES 12288U
#define GATE15_PIPELINE_CHUNK 256U

static int
write_all(int fd, const uint8_t *buffer, size_t size)
{
	size_t written = 0U;

	while (written < size) {
		ssize_t result = write(fd, buffer + written, size - written);

		if (result > 0) {
			written += (size_t)result;
			continue;
		}
		if (result < 0 && errno == EINTR) {
			continue;
		}
		return -1;
	}
	return 0;
}

static int
run_producer(void)
{
	uint8_t buffer[GATE15_PIPELINE_CHUNK];
	unsigned int offset;

	for (offset = 0U; offset < GATE15_PIPELINE_BYTES;
	    offset += sizeof(buffer)) {
		unsigned int i;

		for (i = 0U; i < sizeof(buffer); i++) {
			buffer[i] = (uint8_t)(offset + i);
		}
		if (write_all(STDOUT_FILENO, buffer, sizeof(buffer)) != 0) {
			return 10;
		}
	}
	return 0;
}

static int
run_consumer(void)
{
	uint8_t buffer[257];
	unsigned int total = 0U;
	unsigned int checksum = 0U;

	for (;;) {
		ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
		unsigned int i;

		if (count == 0) {
			break;
		}
		if (count < 0) {
			if (errno == EINTR) {
				continue;
			}
			return 11;
		}
		for (i = 0U; i < (unsigned int)count; i++) {
			if (buffer[i] != (uint8_t)(total + i)) {
				return 12;
			}
			checksum += buffer[i];
		}
		total += (unsigned int)count;
	}
	return total == GATE15_PIPELINE_BYTES && checksum == 1566720U ? 0 : 13;
}

static int
wait_clean(pid_t pid)
{
	int status = 0;
	pid_t result;

	do {
		result = waitpid(pid, &status, 0);
	} while (result < 0 && errno == EINTR);
	return result == pid && WIFEXITED(status) && WEXITSTATUS(status) == 0 ?
	    0 : -1;
}

int
main(int argc, char **argv)
{
	char *end = NULL;
	unsigned long rounds;
	unsigned long round;

	if (argc != 2) {
		return 2;
	}
	errno = 0;
	rounds = strtoul(argv[1], &end, 10);
	if (errno != 0 || end == argv[1] || *end != '\0' || rounds == 0U ||
	    rounds > GATE15_PIPELINE_MAX_ROUNDS) {
		return 3;
	}
	for (round = 0U; round < rounds; round++) {
		int fds[2];
		pid_t producer;
		pid_t consumer;

		if (pipe(fds) != 0) {
			return 5;
		}
		producer = fork();
		if (producer == 0) {
			if (dup2(fds[1], STDOUT_FILENO) < 0) {
				_exit(92);
			}
			(void)close(fds[0]);
			(void)close(fds[1]);
			_exit(run_producer());
		}
		if (producer < 0) {
			return 6;
		}
		consumer = fork();
		if (consumer == 0) {
			if (dup2(fds[0], STDIN_FILENO) < 0) {
				_exit(93);
			}
			(void)close(fds[0]);
			(void)close(fds[1]);
			_exit(run_consumer());
		}
		if (consumer < 0) {
			return 7;
		}
		if (close(fds[0]) != 0 || close(fds[1]) != 0 ||
		    wait_clean(producer) != 0 || wait_clean(consumer) != 0) {
			return 8;
		}
	}
	printf("[process-gate-15] pipelines=%lu processes=%lu transfer-bytes=%lu PASS\n",
	    rounds, rounds * 2U, rounds * GATE15_PIPELINE_BYTES);
	return 0;
}
