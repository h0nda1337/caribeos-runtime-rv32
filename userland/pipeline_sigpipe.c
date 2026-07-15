#include <errno.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

int
main(void)
{
	static const char armed[] =
	    "[pipeline-sigpipe] default disposition armed PASS\n";
	static const char failure[] =
	    "[pipeline-sigpipe] FAIL write returned after default SIGPIPE\n";
	struct sigaction action;
	int fds[2];
	char byte = 'x';

	memset(&action, 0, sizeof(action));
	action.sa_handler = SIG_DFL;
	sigemptyset(&action.sa_mask);
	if (sigaction(SIGPIPE, &action, NULL) != 0 || pipe(fds) != 0 ||
	    close(fds[0]) != 0) {
		return 90;
	}
	(void)write(STDERR_FILENO, armed, sizeof(armed) - 1U);
	errno = 0;
	(void)write(fds[1], &byte, 1U);
	(void)write(STDERR_FILENO, failure, sizeof(failure) - 1U);
	return errno == EPIPE ? 91 : 92;
}
