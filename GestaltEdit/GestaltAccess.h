//
//  GestaltAccess.h
//  GestaltEdit
//
//  iOS 18 local-file backend.
//  Reads/writes a MobileGestalt plist inside the app's Documents directory.
//  No MobileGestalt system path, ContainerManager, sandbox-extension or exploit
//  APIs are used.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GestaltAccess : NSObject

+ (instancetype)shared;
+ (BOOL)isRunningSupportedOS;
+ (NSString *)currentOSBuild;

/// Resolves Documents/MobileGestalt.plist (or com.apple.MobileGestalt.plist).
- (BOOL)connectWithError:(NSError **)error;
- (nullable NSDictionary *)readGestaltWithError:(NSError **)error;
- (nullable NSData *)readGestaltDataWithError:(NSError **)error;
- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
