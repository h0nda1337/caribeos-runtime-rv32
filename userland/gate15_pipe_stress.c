#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define GATE15_PIPE_BYTES 64U
#define GATE15_PIPE_MAX_ROUNDS 1000U

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
read_all(int fd, uint8_t *buffer, size_t size)
{
	size_t consumed = 0U;

	while (consumed < size) {
		ssize_t result = read(fd, buffer + consumed, size - consumed);

		if (result > 0) {
			consumed += (size_t)result;
			continue;
		}
		if (result < 0 && errno == EINTR) {
			continue;
		}
		return -1;
	}
	return 0;
}

int
main(int argc, char **argv)
{
	char *end = NULL;
	unsigned long rounds;
	unsigned int round;
	uint32_t total_bytes = 0U;

	if (argc != 2) {
		return 2;
	}
	errno = 0;
	rounds = strtoul(argv[1], &end, 10);
	if (errno != 0 || end == argv[1] || *end != '\0' || rounds == 0U ||
	    rounds > GATE15_PIPE_MAX_ROUNDS) {
		return 3;
	}
	for (round = 0U; round < (unsigned int)rounds; round++) {
		uint8_t sent[GATE15_PIPE_BYTES];
		uint8_t received[GATE15_PIPE_BYTES];
		int fds[2];
		unsigned int i;

		for (i = 0U; i < GATE15_PIPE_BYTES; i++) {
			sent[i] = (uint8_t)(round + i);
			received[i] = 0U;
		}
		if (pipe(fds) != 0 ||
		    write_all(fds[1], sent, sizeof(sent)) != 0 ||
		    close(fds[1]) != 0 ||
		    read_all(fds[0], received, sizeof(received)) != 0 ||
		    close(fds[0]) != 0) {
			return 4;
		}
		for (i = 0U; i < GATE15_PIPE_BYTES; i++) {
			if (received[i] != sent[i]) {
				return 5;
			}
		}
		total_bytes += GATE15_PIPE_BYTES;
	}
	printf("[process-gate-15] pipes=%lu bytes=%u alloc-close/read-write verified PASS\n",
	    rounds, total_bytes);
	return 0;
}
