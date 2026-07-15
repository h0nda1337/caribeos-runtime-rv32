#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int
main(void)
{
	static const char failure[] =
	    "[jobctl-wait] FAIL read returned without terminating signal\n";
	static const char resumed[] =
	    "[jobctl-wait] resumed after SIGCONT; blocking-read PASS\n";
	struct sigaction action;
	char report[128];
	char byte;
	ssize_t result;
	unsigned int interruptions = 0U;
	pid_t pid = getpid();
	pid_t pgid = getpgrp();
	pid_t foreground = tcgetpgrp(STDIN_FILENO);
	int report_size;

	memset(&action, 0, sizeof(action));
	action.sa_handler = SIG_DFL;
	sigemptyset(&action.sa_mask);
	if (sigaction(SIGINT, &action, NULL) != 0 ||
	    sigaction(SIGQUIT, &action, NULL) != 0 ||
	    sigaction(SIGTSTP, &action, NULL) != 0 ||
	    sigaction(SIGCONT, &action, NULL) != 0 ||
	    foreground != pgid || pgid != pid) {
		return 90;
	}
	report_size = snprintf(report, sizeof(report),
	    "[jobctl-wait] pid=%ld pgid=%ld foreground=%ld blocking-read PASS\n",
	    (long)pid, (long)pgid, (long)foreground);
	if (report_size <= 0 || (size_t)report_size >= sizeof(report) ||
	    write(STDERR_FILENO, report, (size_t)report_size) != report_size) {
		return 91;
	}
	for (;;) {
		errno = 0;
		result = read(STDIN_FILENO, &byte, 1U);
		if (result < 0 && errno == EINTR && interruptions++ == 0U) {
			if (write(STDERR_FILENO, resumed, sizeof(resumed) - 1U) !=
			    (ssize_t)(sizeof(resumed) - 1U)) {
				return 92;
			}
			continue;
		}
		break;
	}
	(void)write(STDERR_FILENO, failure, sizeof(failure) - 1U);
	return 93;
}
