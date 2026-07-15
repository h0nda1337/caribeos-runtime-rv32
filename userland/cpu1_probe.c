#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>

#define GETCPU_ROUNDS 10000U
#define MMAP_ROUNDS 256U
#define TEST_PAGE_SIZE 4096U

int
main(int argc, char **argv)
{
	uint32_t cpu = UINT32_MAX;
	uint32_t node = UINT32_MAX;
	uint32_t checksum = 0U;
	uint32_t getcpu_rounds = GETCPU_ROUNDS;
	uint32_t mmap_rounds = MMAP_ROUNDS;
	uint32_t round;
	int cycle_mode = 0;
	long rc;

	if (argc == 2 && strcmp(argv[1], "--cycle") == 0) {
		cycle_mode = 1;
		getcpu_rounds = 1U;
		mmap_rounds = 1U;
	} else if (argc != 1) {
		fprintf(stderr, "[cpu1-probe] FAIL unknown arguments\n");
		return 19;
	}

	for (round = 0U; round < getcpu_rounds; round++) {
		cpu = UINT32_MAX;
		node = UINT32_MAX;
		rc = syscall(SYS_getcpu, &cpu, &node, NULL);
		if (rc != 0 || cpu != 1U || node != 0U) {
			fprintf(stderr,
			    "[cpu1-probe] FAIL getcpu round=%u rc=%ld errno=%d cpu=%u node=%u\n",
			    round, rc, errno, cpu, node);
			return 20;
		}
	}

	for (round = 0U; round < mmap_rounds; round++) {
		volatile uint32_t *words;
		uint32_t expected = 0xc41b0000U ^ round;

		words = mmap(NULL, TEST_PAGE_SIZE, PROT_READ | PROT_WRITE,
		    MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
		if (words == MAP_FAILED) {
			fprintf(stderr,
			    "[cpu1-probe] FAIL mmap round=%u errno=%d\n",
			    round, errno);
			return 21;
		}
		words[0] = expected;
		words[(TEST_PAGE_SIZE / sizeof(*words)) - 1U] = ~expected;
		if (mprotect((void *)words, TEST_PAGE_SIZE, PROT_READ) != 0 ||
		    words[0] != expected ||
		    words[(TEST_PAGE_SIZE / sizeof(*words)) - 1U] != ~expected) {
			fprintf(stderr,
			    "[cpu1-probe] FAIL translation round=%u errno=%d\n",
			    round, errno);
			return 22;
		}
		checksum ^= words[0] ^ words[
		    (TEST_PAGE_SIZE / sizeof(*words)) - 1U];
		if (munmap((void *)words, TEST_PAGE_SIZE) != 0) {
			fprintf(stderr,
			    "[cpu1-probe] FAIL munmap round=%u errno=%d\n",
			    round, errno);
			return 23;
		}
	}

	if (!cycle_mode) {
		cpu = UINT32_MAX;
		node = UINT32_MAX;
		if (syscall(SYS_getcpu, &cpu, &node, NULL) != 0 || cpu != 1U ||
		    node != 0U) {
			fprintf(stderr,
			    "[cpu1-probe] FAIL final getcpu cpu=%u node=%u\n",
			    cpu, node);
			return 24;
		}
		printf("[cpu1-probe] pid=%ld cpu=%u getcpu-rounds=%u mmap-rounds=%u checksum=0x%08x PASS\n",
		    (long)getpid(), cpu, getcpu_rounds, mmap_rounds, checksum);
	}
	return 0;
}
