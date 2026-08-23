#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <sys/utsname.h>

extern const char *__progname;

static NSString * const kPrefsPath =
    @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist";

static NSString * const kPrefsNotify =
    @"com.julioverne.lowerinstall/SettingsChanged";

static BOOL LIEnabled = YES;

static NSString *LISpoofVersion = nil;
static NSString *LISpoofDevice = nil;
static NSString *LICurrentVersion = nil;
static NSString *LICurrentDevice = nil;


#pragma mark - Device / Version Helpers

static NSString *LIDeviceModel(void)
{
    struct utsname info;

    if (uname(&info) != 0) {
        return @"iPhone";
    }

    NSString *model =
        [NSString stringWithUTF8String:info.machine];

    return model ?: @"iPhone";
}


static NSString *LINormalizedVersion(
    NSString *value,
    NSString *fallback
)
{
    if (![value isKindOfClass:[NSString class]]) {
        return fallback;
    }

    NSString *version =
        [value stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSError *regexError = nil;

    NSRegularExpression *regex =
        [NSRegularExpression
            regularExpressionWithPattern:
                @"^[0-9]{1,2}(\\.[0-9]{1,2}){0,2}$"
            options:0
            error:&regexError];

    if (regexError || !regex) {
        return fallback;
    }

    NSUInteger matches =
        [regex numberOfMatchesInString:version
                               options:0
                                 range:NSMakeRange(0, version.length)];

    if (matches != 1) {
        return fallback;
    }

    return version;
}


#pragma mark - Preferences

static void LILoadPrefs(void)
{
    @autoreleasepool {

        NSDictionary *prefs =
            [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];

        if (!prefs) {
            prefs = @{};
        }

        LICurrentVersion =
            [[UIDevice currentDevice] systemVersion];

        if (!LICurrentVersion.length) {
            LICurrentVersion = @"16.0";
        }

        LICurrentDevice = LIDeviceModel();

        id enabledValue = prefs[@"Enabled"];

        LIEnabled =
            enabledValue ? [enabledValue boolValue] : YES;

        LISpoofVersion =
            LINormalizedVersion(
                prefs[@"SpoofVersion"],
                LICurrentVersion
            );

        NSString *deviceValue = nil;

        if ([prefs[@"SpoofDevice"]
                isKindOfClass:[NSString class]]) {

            deviceValue = prefs[@"SpoofDevice"];
        }

        if (deviceValue.length) {
            LISpoofDevice = deviceValue;
        } else {
            LISpoofDevice = LICurrentDevice;
        }
    }
}


static void LIPrefsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    LILoadPrefs();
}


#pragma mark - App Store Hooks

%group StoreHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value
forHTTPHeaderField:(NSString *)field
{
    if (!LIEnabled ||
        !value.length ||
        !field.length ||
        [field caseInsensitiveCompare:@"User-Agent"] != NSOrderedSame) {

        %orig(value, field);
        return;
    }

    NSString *newValue = value;

    if (LICurrentVersion.length &&
        LISpoofVersion.length &&
        ![LICurrentVersion isEqualToString:LISpoofVersion]) {

        newValue =
            [newValue
                stringByReplacingOccurrencesOfString:
                    LICurrentVersion
                withString:
                    LISpoofVersion];
    }

    if (LICurrentDevice.length &&
        LISpoofDevice.length &&
        ![LICurrentDevice isEqualToString:LISpoofDevice]) {

        newValue =
            [newValue
                stringByReplacingOccurrencesOfString:
                    LICurrentDevice
                withString:
                    LISpoofDevice];
    }

    %orig(newValue, field);
}

%end

%end


#pragma mark - MobileInstallation Hooks

%group InstallHooks


%hook MIDaemonConfiguration

- (BOOL)skipDeviceFamilyCheck
{
    if (LIEnabled) {
        return YES;
    }

    return %orig;
}


- (BOOL)skipThinningCheck
{
    if (LIEnabled) {
        return YES;
    }

    return %orig;
}

%end


%hook MIBundle

- (NSString *)minimumOSVersion
{
    if (LIEnabled) {
        return @"2.0";
    }

    return %orig;
}


- (BOOL)isCompatibleWithDeviceFamily:(int)device
{
    if (LIEnabled) {
        return YES;
    }

    return %orig(device);
}


- (BOOL)isApplicableToCurrentDeviceFamilyWithError:(id *)error
{
    if (LIEnabled) {

        if (error) {
            *error = nil;
        }

        return YES;
    }

    return %orig(error);
}


- (BOOL)isApplicableToCurrentOSVersionWithError:(id *)error
{
    if (LIEnabled) {

        if (error) {
            *error = nil;
        }

        return YES;
    }

    return %orig(error);
}


- (BOOL)isApplicableToOSVersion:(id)version
                          error:(id *)error
{
    if (LIEnabled) {

        if (error) {
            *error = nil;
        }

        return YES;
    }

    return %orig(version, error);
}


- (BOOL)isApplicableToCurrentDeviceCapabilitiesWithError:(id *)error
{
    if (LIEnabled) {

        if (error) {
            *error = nil;
        }

        return YES;
    }

    return %orig(error);
}


- (BOOL)thinningMatchesCurrentDeviceWithError:(id *)error
{
    if (LIEnabled) {

        if (error) {
            *error = nil;
        }

        return YES;
    }

    return %orig(error);
}

%end

%end


#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        LILoadPrefs();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            LIPrefsChanged,
            (__bridge CFStringRef)kPrefsNotify,
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );

        NSString *process =
            [NSString stringWithUTF8String:
                (__progname ? __progname : "")];

        if ([process isEqualToString:@"appstored"] ||
    [process isEqualToString:@"itunesstored"] ||
    [process isEqualToString:@"storekitd"] ||
    [process isEqualToString:@"AppStore"]) {

    %init(StoreHooks);

} else if ([process isEqualToString:@"installd"]) {

    %init(InstallHooks);
}
    }
}
