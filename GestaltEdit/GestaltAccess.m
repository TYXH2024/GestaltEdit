//
//  GestaltAccess.m
//  GestaltEdit
//
//  Local-file backend for iOS 18 testing.
//  The only file touched is inside this app's sandbox.
//

#import "GestaltAccess.h"

static NSError *GestaltError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"com.gestaltedit.access"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

@interface GestaltAccess ()
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@end

@implementation GestaltAccess

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

+ (NSString *)currentOSBuild
{
    return NSProcessInfo.processInfo.operatingSystemVersionString ?: @"";
}

+ (BOOL)isRunningSupportedOS
{
    return YES;
}

- (NSString *)documentsDirectory
{
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
        URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    return urls.firstObject.path ?: @"";
}

- (BOOL)connectWithError:(NSError **)error
{
    if (self.isConnected && self.plistPath.length > 0) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.plistPath]) {
            if (error) *error = nil;
            return YES;
        }
        self.isConnected = NO;
        self.plistPath = nil;
    }

    NSString *documents = [self documentsDirectory];
    if (documents.length == 0) {
        if (error) *error = GestaltError(1, @"Unable to locate the app Documents directory.");
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candidates = @[
        [documents stringByAppendingPathComponent:@"MobileGestalt.plist"],
        [documents stringByAppendingPathComponent:@"com.apple.MobileGestalt.plist"]
    ];

    for (NSString *candidate in candidates) {
        if ([fm fileExistsAtPath:candidate]) {
            self.plistPath = candidate;
            self.isConnected = YES;
            if (error) *error = nil;
            return YES;
        }
    }

    NSString *message = [NSString stringWithFormat:
        @"Place MobileGestalt.plist in the app Documents directory.\n\nExpected path:\n%@",
        candidates.firstObject];
    if (error) *error = GestaltError(2, message);
    return NO;
}

- (NSData *)readGestaltDataWithError:(NSError **)error
{
    if (![self connectWithError:error]) return nil;

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.plistPath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readError];
    if (!data) {
        if (error) *error = readError ?: GestaltError(3, @"Failed to read the local MobileGestalt plist.");
        return nil;
    }

    if (error) *error = nil;
    return data;
}

- (NSDictionary *)readGestaltWithError:(NSError **)error
{
    NSData *data = [self readGestaltDataWithError:error];
    if (!data) return nil;

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *parseError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:&format
                                                           error:&parseError];

    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = parseError ?: GestaltError(4, @"The local MobileGestalt plist top level is not a dictionary.");
        return nil;
    }

    self.lastReadFormat = format;
    if (error) *error = nil;
    return plist;
}

- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error
{
    if (![self connectWithError:error]) return NO;

    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(5, @"The content to save is not a dictionary.");
        return NO;
    }

    NSPropertyListFormat format = self.lastReadFormat;
    if (format != NSPropertyListXMLFormat_v1_0 &&
        format != NSPropertyListBinaryFormat_v1_0) {
        format = NSPropertyListBinaryFormat_v1_0;
    }

    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                               format:format
                                                              options:0
                                                                error:&serializeError];
    if (!data) {
        if (error) *error = serializeError ?: GestaltError(6, @"Failed to serialize the local plist.");
        return NO;
    }

    NSURL *url = [NSURL fileURLWithPath:self.plistPath];
    NSError *writeError = nil;
    if (![data writeToURL:url options:NSDataWritingAtomic error:&writeError]) {
        if (error) *error = writeError ?: GestaltError(7, @"Failed to write the local MobileGestalt plist.");
        return NO;
    }

    NSData *verification = [NSData dataWithContentsOfURL:url options:0 error:&writeError];
    if (!verification || ![verification isEqualToData:data]) {
        if (error) *error = writeError ?: GestaltError(8, @"Post-write verification of the local plist failed.");
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

@end
