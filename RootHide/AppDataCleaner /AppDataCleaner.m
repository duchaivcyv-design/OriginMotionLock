#include <Foundation/Foundation.h>

#import "AppDelegate.h"
#import "AppInfo.h"
#include "roothide.h"

#ifndef DEBUG
#define NSLog(...)
#endif

BOOL isUUIDPathOf(NSString* path, NSString* parent);

NSString* clearAppData(AppInfo* app)
{
    NSString* error = nil;
    NSLog(@"app.containerURL=%@", app.containerURL);
    
    // Sử dụng jbroot() để bao bọc đường dẫn hệ thống tiêu chuẩn cho môi trường rootless
    NSString *baseContainerPath = @(jbroot("/private/var/mobile/Containers/Data/Application/"));
    
    if(app.containerURL
       && isUUIDPathOf(app.containerURL.path, baseContainerPath)
       && [NSFileManager.defaultManager fileExistsAtPath:app.containerURL.path])
    {
        if([NSFileManager.defaultManager removeItemAtURL:app.containerURL error:&error]) {
            NSLog(@"removed %@", app.containerURL);
        } else {
            error = [NSString stringWithFormat:Localized(@"Failed to remove app data container:\n%@"), error];
        }
    }
    return error;
}
