#import <substrate.h>
#import <unistd.h>
#import <sys/stat.h>
#import <string.h>
#import <errno.h>

static BOOL checkPath(const char *path) {
    if (!path) return NO;
    
    const char *targets[] = {"/var/jb", "sileo", "cydia", "apt", "Zebra", "substitute", "ellekit", NULL};
    for (int i = 0; targets[i] != NULL; i++) {
        if (strstr(path, targets[i])) {
            return YES;
        }
    }
    return NO;
}

static int (*orig_access)(const char *path, int mode);
static int replacement_access(const char *path, int mode) {
    if (checkPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(path, mode);
}

static int (*orig_stat)(const char *path, struct stat *buf);
static int replacement_stat(const char *path, struct stat *buf) {
    if (checkPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_stat(path, buf);
}

%ctor {
    MSHookFunction((void *)access, (void *)replacement_access, (void **)&orig_access);
    MSHookFunction((void *)stat, (void *)replacement_stat, (void **)&orig_stat);
}
