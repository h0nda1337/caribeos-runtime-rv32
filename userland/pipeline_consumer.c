/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define PIPELINE_TOTAL_BYTES 12288U
#define PIPELINE_EXPECTED_SUM 1566720U

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
	uint8_t buffer[257];
	char report[160];
	uint32_t total = 0U;
	uint32_t checksum = 0U;
	uint32_t mismatches = 0U;
	int text_mode = argc == 2 && strcmp(argv[1], "--text") == 0;
	int report_size;

	for (;;) {
		ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
		uint32_t i;

		if (count == 0) {
			break;
		}
		if (count < 0) {
			if (errno == EINTR) {
				continue;
			}
			return 4;
		}
		for (i = 0U; i < (uint32_t)count; i++) {
			checksum += buffer[i];
			if (!text_mode && buffer[i] != (uint8_t)(total + i)) {
				mismatches++;
			}
		}
		total += (uint32_t)count;
	}

	if (text_mode) {
		report_size = snprintf(report, sizeof(report),
		    "[pipeline-consumer] redirected input bytes=%u PASS\n", total);
	} else {
		if (total != PIPELINE_TOTAL_BYTES ||
		    checksum != PIPELINE_EXPECTED_SUM || mismatches != 0U) {
			report_size = snprintf(report, sizeof(report),
			    "[pipeline-consumer] FAIL bytes=%u checksum=%u mismatches=%u\n",
			    total, checksum, mismatches);
			(void)write_all(STDERR_FILENO, report, (size_t)report_size);
			return 5;
		}
		report_size = snprintf(report, sizeof(report),
		    "[pipeline-consumer] bytes=%u checksum=%u pattern=sequential PASS\n",
		    total, checksum);
	}
	if (report_size <= 0 || (size_t)report_size >= sizeof(report) ||
	    write_all(STDOUT_FILENO, report, (size_t)report_size) != 0) {
		return 6;
	}
	return 0;
}
