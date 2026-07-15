#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define GATE15_BATCH_MAX 10U
#define GATE15_BATCHES_MAX 10U

static unsigned long
parse_count(const char *text, unsigned long maximum)
{
	char *end = NULL;
	unsigned long value;

	errno = 0;
	value = strtoul(text, &end, 10);
	return errno == 0 && end != text && *end == '\0' && value != 0U &&
	    value <= maximum ? value : 0U;
}

int
main(int argc, char **argv)
{
	pid_t children[GATE15_BATCH_MAX];
	unsigned long batches;
	unsigned long width;
	unsigned long batch;
	unsigned int completed = 0U;

	if (argc != 3) {
		return 2;
	}
	batches = parse_count(argv[1], GATE15_BATCHES_MAX);
	width = parse_count(argv[2], GATE15_BATCH_MAX);
	if (batches == 0U || width == 0U) {
		return 3;
	}
	for (batch = 0U; batch < batches; batch++) {
		unsigned long i;

		for (i = 0U; i < width; i++) {
			children[i] = fork();
			if (children[i] == 0) {
				_exit(0);
			}
			if (children[i] < 0) {
				return 4;
			}
		}
		for (i = width; i != 0U; i--) {
			int status = 0;
			pid_t result;

			do {
				result = waitpid(children[i - 1U], &status, 0);
			} while (result < 0 && errno == EINTR);
			if (result != children[i - 1U] || !WIFEXITED(status) ||
			    WEXITSTATUS(status) != 0) {
				return 5;
			}
			completed++;
		}
	}
	printf("[process-gate-15] child-batches=%lu batch-width=%lu fork-exit-wait=%u zombies=0 PASS\n",
	    batches, width, completed);
	return 0;
}
