/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#define PIPELINE_TOTAL_BYTES 12288U
#define PIPELINE_CHUNK_BYTES 256U

static int
write_all(int fd, const void *buffer, size_t size)
{
	const uint8_t *bytes = (const uint8_t *)buffer;
	size_t written = 0U;

	while (written < size) {
		ssize_t result = write(fd, bytes + written, size - written);

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

int
main(int argc, char **argv)
{
	uint8_t buffer[PIPELINE_CHUNK_BYTES];
	uint32_t offset;
	uint32_t i;
	static const char stderr_message[] =
	    "[pipeline-producer] stderr redirection PASS\n";

	if (argc == 2 && strcmp(argv[1], "--stderr") == 0) {
		return write_all(STDERR_FILENO, stderr_message,
		    sizeof(stderr_message) - 1U) == 0 ? 0 : 2;
	}
	for (offset = 0U; offset < PIPELINE_TOTAL_BYTES;
	    offset += PIPELINE_CHUNK_BYTES) {
		for (i = 0U; i < sizeof(buffer); i++) {
			buffer[i] = (uint8_t)(offset + i);
		}
		if (write_all(STDOUT_FILENO, buffer, sizeof(buffer)) != 0) {
			return 3;
		}
	}
	return 0;
}
