// Run on macOS, as the logged-in user (not root):
// xcrun clang -fobjc-arc -framework Foundation .github/tests/LCFileDeletionTests.m -o /tmp/lc-deletion-tests
#import "../../LiveContainer/LCFileDeletion.h"
#include <unistd.h>

static void Check(BOOL condition, NSString *message) {
    if (!condition) @throw [NSException exceptionWithName:@"DeletionTestFailure" reason:message userInfo:nil];
}

static void MakeDirectory(NSURL *url) {
    NSError *error = nil;
    Check([NSFileManager.defaultManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error], error.description);
}

static void WriteFile(NSURL *url) {
    Check([@"sentinel" writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil], @"write fixture");
}

static void Remove(NSURL *url) {
    NSError *error = nil;
    Check(LCRemoveItemUnlocking(url, &error), error.description);
    struct stat info;
    Check(lstat(url.fileSystemRepresentation, &info) != 0 && errno == ENOENT, @"entry was removed");
}

static void RunChmod(NSArray<NSString *> *arguments) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/chmod"];
    task.arguments = arguments;
    NSError *error = nil;
    Check([task launchAndReturnError:&error], error.description);
    [task waitUntilExit];
    Check(task.terminationStatus == 0, @"chmod ACL fixture");
}

int main(void) {
    @autoreleasepool {
        Check(geteuid() != 0, @"Run as a non-root user so permission checks are exercised");
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        MakeDirectory(root);
        int status = 0;
        @try {
            NSURL *tree = [root URLByAppendingPathComponent:@"tree"];
            NSURL *nested = [tree URLByAppendingPathComponent:@"nested/deep"];
            MakeDirectory(nested);
            WriteFile([nested URLByAppendingPathComponent:@"save"]);
            Check(chmod(nested.fileSystemRepresentation, 0) == 0, @"lock nested directory");
            Check(chmod(tree.fileSystemRepresentation, 0500) == 0, @"read-only tree");
            Remove(tree);

            NSURL *parent = [root URLByAppendingPathComponent:@"parent"];
            NSURL *child = [parent URLByAppendingPathComponent:@"child"];
            MakeDirectory(parent);
            WriteFile(child);
            Check(chmod(parent.fileSystemRepresentation, 0550) == 0, @"read-only parent");
            Check(chflags(parent.fileSystemRepresentation, UF_IMMUTABLE | UF_APPEND) == 0, @"lock parent flags");
            Remove(child);
            struct stat info;
            Check(lstat(parent.fileSystemRepresentation, &info) == 0, @"stat parent");
            Check((info.st_mode & 0777) == 0750, @"only owner permissions added to parent");
            Check((info.st_flags & (UF_IMMUTABLE | UF_APPEND)) == 0, @"parent deletion flags cleared");

            NSURL *locked = [root URLByAppendingPathComponent:@"locked"];
            MakeDirectory(locked);
            NSURL *lockedFile = [locked URLByAppendingPathComponent:@"file"];
            WriteFile(lockedFile);
            Check(chflags(lockedFile.fileSystemRepresentation, UF_IMMUTABLE | UF_APPEND) == 0, @"lock file flags");
            Check(chflags(locked.fileSystemRepresentation, UF_IMMUTABLE) == 0, @"lock tree flags");
            Remove(locked);

            NSURL *contentsRoot = [root URLByAppendingPathComponent:@"contents"];
            MakeDirectory(contentsRoot);
            NSURL *metadata = [contentsRoot URLByAppendingPathComponent:@"LCContainerInfo.plist"];
            WriteFile(metadata);
            WriteFile([contentsRoot URLByAppendingPathComponent:@"payload"]);
            Check(chmod(contentsRoot.fileSystemRepresentation, 0) == 0, @"inaccessible contents root");
            NSError *listingError = nil;
            NSArray<NSURL *> *contents = LCContentsForDeletion(contentsRoot, &listingError);
            Check(contents.count == 2, listingError.description ?: @"enumerate inaccessible directory");
            for (NSURL *item in contents) {
                if (![item.lastPathComponent isEqual:@"LCContainerInfo.plist"]) Remove(item);
            }
            Check([NSFileManager.defaultManager fileExistsAtPath:metadata.path], @"preserved container metadata");

            NSURL *outside = [root URLByAppendingPathComponent:@"outside"];
            NSURL *sentinel = [outside URLByAppendingPathComponent:@"sentinel"];
            MakeDirectory(outside);
            WriteFile(sentinel);
            Check(chmod(outside.fileSystemRepresentation, 0500) == 0, @"protect target permissions");
            Check(chflags(outside.fileSystemRepresentation, UF_IMMUTABLE) == 0, @"protect target flags");
            NSURL *links = [root URLByAppendingPathComponent:@"links"];
            MakeDirectory(links);
            Check(symlink(outside.fileSystemRepresentation, [links URLByAppendingPathComponent:@"tmp"].fileSystemRepresentation) == 0, @"directory symlink");
            Check(symlink("/does-not-exist", [links URLByAppendingPathComponent:@"dangling"].fileSystemRepresentation) == 0, @"dangling symlink");
            Check(chmod(links.fileSystemRepresentation, 0500) == 0, @"force preparation of links");
            Remove(links);
            Check(lstat(outside.fileSystemRepresentation, &info) == 0, @"target survives");
            Check((info.st_mode & 0777) == 0500 && (info.st_flags & UF_IMMUTABLE), @"target attributes unchanged");
            Check([NSFileManager.defaultManager fileExistsAtPath:sentinel.path], @"target data unchanged");

            NSURL *rootLink = [root URLByAppendingPathComponent:@"root-link"];
            Check(symlink(outside.fileSystemRepresentation, rootLink.fileSystemRepresentation) == 0, @"root symlink");
            listingError = nil;
            Check(!LCContentsForDeletion(rootLink, &listingError) && listingError, @"clearing a link must not enumerate its target");
            Remove(rootLink);
            Check([NSFileManager.defaultManager fileExistsAtPath:sentinel.path], @"root symlink does not remove target");
            Remove([root URLByAppendingPathComponent:@"already-missing"]);

            // An ACL rejection is not fixed by chmod. It must retain the item
            // and return a useful error containing both the path and errno.
            NSURL *denied = [root URLByAppendingPathComponent:@"denied"];
            WriteFile(denied);
            RunChmod(@[@"+a", @"everyone deny delete", denied.path]);
            NSError *error = nil;
            Check(!LCRemoveItemUnlocking(denied, &error), @"ACL deletion rejected");
            Check([error.localizedDescription containsString:denied.path] && error.userInfo[NSUnderlyingErrorKey], @"detailed deletion error");
            RunChmod(@[@"-N", denied.path]);
            Remove(denied);

            error = nil;
            Check(!LCRemoveItemUnlocking([NSURL fileURLWithPath:@"/"], &error) && error, @"filesystem root rejected");
            Check(!LCRemoveItemUnlocking([NSURL URLWithString:@"https://example.com/file"], &error), @"non-file URL rejected");
            NSLog(@"PASS: nested permissions, parent permissions, immutable/append flags, symlinks, missing items, ACL diagnostics, invalid roots");
        } @catch (NSException *exception) {
            NSLog(@"FAIL: %@", exception);
            status = 1;
        } @finally {
            // Also unlock fixtures deliberately retained by the symlink tests.
            NSMutableArray *errors = [NSMutableArray array];
            LCPrepareItemForDeletion(root, NO, errors);
            [NSFileManager.defaultManager removeItemAtURL:root error:nil];
        }
        return status;
    }
}
