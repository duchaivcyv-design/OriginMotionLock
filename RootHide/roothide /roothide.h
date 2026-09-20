#ifndef ROOTHIDE_H
#define ROOTHIDE_H

#pragma message("roothide header adapted for rootless environment...")

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnullability-completeness"

#include <string.h>

#ifdef __cplusplus
#include <string>
#endif

#ifdef __OBJC__
#import <Foundation/NSString.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

static inline const char* rootfs_alloc(const char* path) { return path ? strdup(path) : NULL; }
static inline const char* jbroot_alloc(const char* path) { return path ? strdup(path) : NULL; }
static inline const char* jbrootat_alloc(int fd, const char* path) { return path ? strdup(path) : NULL; }

// 

/* Trả về giá trị ngẫu nhiên cố định cho môi trường rootless */
static inline unsigned long long jbrand() { return 0; }

/* Trả về nguyên bản đường dẫn trong rootless */
static inline const char* jbroot(const char* path) { return path; }

/* Trả về nguyên bản đường dẫn trong rootless */
static inline const char* rootfs(const char* path) { return path; }

#ifdef __OBJC__
static inline NSString* _Nonnull __attribute__((overloadable)) jbroot(NSString* _Nonnull path) { return path; }
static inline NSString* _Nonnull __attribute__((overloadable)) rootfs(NSString* _Nonnull path) { return path; }
#endif

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
static inline std::string jbroot(std::string path) { return path; }
static inline std::string rootfs(std::string path) { return path; }
#endif

#pragma GCC diagnostic pop

#endif /* ROOTHIDE_H */
