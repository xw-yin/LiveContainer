@import Foundation;

@interface LCSharedUtils : NSObject
+ (BOOL)removeItemUnlockingAtURL:(NSURL * _Nonnull)url error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NAME(removeItemUnlocking(at:));
+ (NSArray<NSURL *> * _Nullable)contentsForDeletionAtURL:(NSURL * _Nonnull)url error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NAME(contentsForDeletion(at:));
+ (NSString*) teamIdentifier;
+ (NSString *)appGroupID;
+ (NSURL*) appGroupPath;
+ (NSString *)certificatePassword;
+ (BOOL)launchToGuestAppWithClassicMode:(NSUInteger)classicMode;
+ (BOOL)launchToGuestAppWithURL:(NSURL *)url;
+ (void)setWebPageUrlForNextLaunch:(NSString*)urlString;
+ (BOOL)isLCSchemeInUse:(NSString*)lc;
+ (NSString*)getContainerUsingLCSchemeWithFolderName:(NSString*)folderName;
+ (void)setContainerUsingByLC:(NSString*)lc folderName:(NSString*)folderName auditToken:(uint64_t)val57;
+ (void)moveSharedAppFolderBack;
+ (NSBundle*)findBundleWithBundleId:(NSString*)bundleId isSharedAppOut:(bool*)isSharedAppOut;
+ (void)dumpPreferenceToPath:(NSString*)plistLocationTo dataUUID:(NSString*)dataUUID;
+ (NSString*)findDefaultContainerWithBundleId:(NSString*)bundleId;
+ (NSArray<NSString*>*)lcUnorderedUrlSchemes;
+ (NSArray<NSString*>*)lcUrlSchemes;
@end
