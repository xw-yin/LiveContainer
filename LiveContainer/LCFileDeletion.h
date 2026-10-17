// Shared by the host, SwiftUI management UI, and the deletion regression tests.
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <errno.h>

static NSError *LCDeletionPOSIXError(NSString *path, NSString *operation, int code) {
    NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{
        NSFilePathErrorKey: path,
        NSUnderlyingErrorKey: underlying,
        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@: %@\n%@ (%@ %ld)",
            operation, path, underlying.localizedDescription, underlying.domain, (long)underlying.code]
    }];
}

// lstat/lchflags/lchmod deliberately operate on the link itself. A guest's tmp
// link can point outside the container, including at another app's active data.
static BOOL LCPrepareItemForDeletion(NSURL *url, BOOL parentOnly, NSMutableArray<NSError *> *errors) {
    struct stat info;
    if (lstat(url.fileSystemRepresentation, &info) != 0) {
        int code = errno;
        if (code == ENOENT) return YES;
        [errors addObject:LCDeletionPOSIXError(url.path, @"lstat", code)];
        return NO;
    }

    // Clear only owner-changeable deletion flags, preserving all other flags.
    u_int flags = info.st_flags & ~(UF_IMMUTABLE | UF_APPEND);
    if (flags != info.st_flags && lchflags(url.fileSystemRepresentation, flags) != 0) {
        [errors addObject:LCDeletionPOSIXError(url.path, @"lchflags", errno)];
    }
    if (!S_ISDIR(info.st_mode)) return YES;

    mode_t required = parentOnly ? (S_IWUSR | S_IXUSR) : S_IRWXU;
    if ((info.st_mode & required) != required &&
        lchmod(url.fileSystemRepresentation, (info.st_mode & ALLPERMS) | required) != 0) {
        [errors addObject:LCDeletionPOSIXError(url.path, @"lchmod", errno)];
        return NO;
    }
    if (parentOnly) return YES;

    NSError *error = nil;
    NSArray<NSURL *> *children = [NSFileManager.defaultManager contentsOfDirectoryAtURL:url
        includingPropertiesForKeys:nil options:0 error:&error];
    if (!children) {
        [errors addObject:error];
        return NO;
    }
    for (NSURL *child in children) {
        // Continue preparing siblings even if one child cannot be unlocked.
        LCPrepareItemForDeletion(child, NO, errors);
    }
    return YES;
}

static BOOL LCRemoveItemUnlocking(NSURL *url, NSError **error) {
    // Reject empty/root URLs before any permission change. Callers must supply
    // the exact item; browser callers additionally enforce their browsing root.
    NSString *path = url.path;
    if (!url.isFileURL || !path.isAbsolutePath || path.length <= 1 ||
        [path.pathComponents containsObject:@".."] || [path.pathComponents containsObject:@"."]) {
        if (error) *error = LCDeletionPOSIXError(path ?: @"", @"Invalid deletion path", EINVAL);
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *initialError = nil;
    if ([fm removeItemAtURL:url error:&initialError]) return YES;

    struct stat info;
    if (lstat(url.fileSystemRepresentation, &info) != 0 && errno == ENOENT) {
        // Cleanup is idempotent, including dangling links (lstat finds those).
        return YES;
    }

    // Do not chmod files to repair unrelated failures such as a read-only volume.
    NSError *cause = initialError;
    BOOL permissionFailure = NO;
    for (NSUInteger depth = 0; cause && depth < 16; depth++) {
        if (([cause.domain isEqual:NSPOSIXErrorDomain] && (cause.code == EACCES || cause.code == EPERM)) ||
            ([cause.domain isEqual:NSCocoaErrorDomain] &&
             (cause.code == NSFileWriteNoPermissionError || cause.code == NSFileReadNoPermissionError))) {
            permissionFailure = YES;
        }
        cause = cause.userInfo[NSUnderlyingErrorKey];
    }
    NSMutableArray<NSError *> *preparationErrors = [NSMutableArray array];
    NSError *removalError = initialError;
    if (permissionFailure) {
        // Removing the top-level entry also needs write/search permission on
        // its parent. Resolve system aliases (/var) for this parent only.
        NSURL *parent = url.URLByDeletingLastPathComponent.URLByResolvingSymlinksInPath;
        LCPrepareItemForDeletion(parent, YES, preparationErrors);
        LCPrepareItemForDeletion(url, NO, preparationErrors);
        if ([fm removeItemAtURL:url error:&removalError]) return YES;
        if (lstat(url.fileSystemRepresentation, &info) != 0 && errno == ENOENT) return YES;
    }

    if (error) {
        NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObjects:
            removalError.localizedDescription, path, nil];
        for (NSError *preparationError in preparationErrors) {
            [details addObject:preparationError.localizedDescription];
        }
        // Include the failing descendant and underlying errno, not just the
        // generic Foundation permission message for the container's name.
        cause = removalError;
        for (NSUInteger depth = 0; cause && depth < 16; depth++) {
            [details addObject:[NSString stringWithFormat:@"%@ %ld: %@", cause.domain,
                (long)cause.code, cause.userInfo[NSFilePathErrorKey] ?: cause.localizedDescription]];
            cause = cause.userInfo[NSUnderlyingErrorKey];
        }
        *error = [NSError errorWithDomain:removalError.domain code:removalError.code userInfo:@{
            NSLocalizedDescriptionKey: [details componentsJoinedByString:@"\n"],
            NSFilePathErrorKey: path,
            NSUnderlyingErrorKey: removalError,
            @"LCDeletionPreparationErrors": preparationErrors
        }];
    }
    return NO;
}

static NSArray<NSURL *> *LCContentsForDeletion(NSURL *url, NSError **error) {
    struct stat info;
    if (lstat(url.fileSystemRepresentation, &info) != 0) {
        int code = errno;
        if (code == ENOENT) return @[];
        if (error) *error = LCDeletionPOSIXError(url.path, @"lstat", code);
        return nil;
    }
    // Clearing a directory must never enumerate a symlink's target.
    if (!S_ISDIR(info.st_mode)) {
        if (error) *error = LCDeletionPOSIXError(url.path, @"Expected a directory, not a link", ENOTDIR);
        return nil;
    }
    NSError *listingError = nil;
    NSArray *items = [NSFileManager.defaultManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:&listingError];
    if (items) return items;
    NSMutableArray<NSError *> *errors = [NSMutableArray array];
    LCPrepareItemForDeletion(url, NO, errors);
    items = [NSFileManager.defaultManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:&listingError];
    if (!items && error) *error = errors.firstObject ?: listingError;
    return items;
}
