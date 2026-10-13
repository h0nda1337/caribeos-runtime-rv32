/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
extern char **environ;
struct session {
    const char *name, *program, *status;
};
static const struct session sessions[] = {
    {"syllable", "/bin/syllable-component", "AppServer decorator component only"},
    {"wayland", NULL, "blocked: AF_UNIX/SCM_RIGHTS/shared VM/epoll"},
    {"x11", NULL, "blocked: Wayland compositor and Xwayland port"}};
int main(int argc, char **argv) {
    char selected[48] = "syllable", line[80];
    unsigned int i;
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc == 2 && !strcmp(argv[1], "--list")) {
        for (i = 0; i < sizeof(sessions) / sizeof(sessions[0]); i++)
            printf("%s: %s\n", sessions[i].name, sessions[i].status);
        return 0;
    }
    if (argc > 2)
        return 2;
    if (argc == 2) {
        if (strlen(argv[1]) >= sizeof(selected))
            return 2;
        strcpy(selected, argv[1]);
    } else {
        FILE *config = fopen("/etc/caribe/session.conf", "r");
        if (!config) {
            perror("session.conf");
            return 1;
        }
        if (!fgets(line, sizeof(line), config) || strncmp(line, "session=", 8)) {
            fclose(config);
            return 2;
        }
        line[strcspn(line, "\r\n")] = 0;
        if (strlen(line + 8) >= sizeof(selected)) {
            fclose(config);
            return 2;
        }
        strcpy(selected, line + 8);
        fclose(config);
    }
    for (i = 0; i < sizeof(sessions) / sizeof(sessions[0]); i++) {
        if (strcmp(selected, sessions[i].name))
            continue;
        printf("[session] %s: %s; config=read-only-initrd; pid=%ld\n", selected, sessions[i].status,
               (long)getpid());
        if (!sessions[i].program)
            return 3;
        char *args[] = {(char *)sessions[i].program, NULL};
        execve(sessions[i].program, args, environ);
        perror("session execve");
        return 1;
    }
    fprintf(stderr, "Unknown session: %s\n", selected);
    return 2;
}
