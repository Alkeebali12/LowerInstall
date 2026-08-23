#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <sys/utsname.h>

extern const char *__progname;

static NSString * const kPrefsPath = @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist";
static NSString * const kPrefsNotify = @"com.julioverne.lowerinstall/SettingsChanged";

static BOOL LIEnabled = YES;
static NSString *LISpoofVersion;
static NSString *LISpoofDevice;
static NSString *LICurrentVersion;
static NSString *LICurrentDevice;

static NSString *LIDeviceModel(void) {
    struct utsname info;
    if (uname(&info) != 0) return @"iPhone";
    return [NSString stringWithUTF8String:info.machine] ?: @"iPhone";
}

static NSString *LINormalizedVersion(NSString *value, NSString *fallback) {
    if (![value isKindOfClass:NSString.class]) return fallback;
    NSString *v = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,2}(\\.[0-9]{1,2}){0,2}$" options:0 error:nil];
    if ([re numberOfMatchesInString:v options:0 range:NSMakeRange(0, v.length)] != 1) return fallback;
    return v;
}

static void LILoadPrefs(void) {
    @autoreleasepool {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: @{};
        LICurrentVersion = UIDevice.currentDevice.systemVersion ?: @"16.0";
        LICurrentDevice = LIDeviceModel();
        LIEnabled = [prefs[@"Enabled"] ?: @YES boolValue];
        LISpoofVersion = LINormalizedVersion(prefs[@"SpoofVersion"], LICurrentVersion);
        NSString *dev = [prefs[@"SpoofDevice"] isKindOfClass:NSString.class] ? prefs[@"SpoofDevice"] : LICurrentDevice;
        LISpoofDevice = dev.length ? dev : LICurrentDevice;
    }
}

static void LIPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    LILoadPrefs();
}

%group StoreHooks

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (!LIEnabled || !value.length || !field.length || [field caseInsensitiveCompare:@"User-Agent"] != NSOrderedSame) {
        %orig(value, field);
        return;
    }
    NSString *newValue = value;
    if (LICurrentVersion.length && LISpoofVersion.length && ![LICurrentVersion isEqualToString:LISpoofVersion]) {
        newValue = [newValue stringByReplacingOccurrencesOfString:LICurrentVersion withString:LISpoofVersion];
    }
    if (LICurrentDevice.length && LISpoofDevice.length && ![LICurrentDevice isEqualToString:LISpoofDevice]) {
        newValue = [newValue stringByReplacingOccurrencesOfString:LICurrentDevice withString:LISpoofDevice];
    }
    %orig(newValue, field);
}
%end

%end

%group InstallHooks

%hook MIDaemonConfiguration
- (BOOL)skipDeviceFamilyCheck { return LIEnabled ? YES : %orig; }
- (BOOL)skipThinningCheck { return LIEnabled ? YES : %orig; }
%end

%hook MIBundle
- (NSString *)minimumOSVersion { return LIEnabled ? @"2.0" : %orig; }
- (BOOL)isCompatibleWithDeviceFamily:(int)device { return LIEnabled ? YES : %orig; }
- (BOOL)isApplicableToCurrentDeviceFamilyWithError:(id *)error { if (LIEnabled) { if (error) *error = nil; return YES; } return %orig; }
- (BOOL)isApplicableToCurrentOSVersionWithError:(id *)error { if (LIEnabled) { if (error) *error = nil; return YES; } return %orig; }
- (BOOL)isApplicableToOSVersion:(id)version error:(id *)error { if (LIEnabled) { if (error) *error = nil; return YES; } return %orig; }
- (BOOL)isApplicableToCurrentDeviceCapabilitiesWithError:(id *)error { if (LIEnabled) { if (error) *error = nil; return YES; } return %orig; }
- (BOOL)thinningMatchesCurrentDeviceWithError:(id *)error { if (LIEnabled) { if (error) *error = nil; return YES; } return %orig; }
%end

%end

%ctor {
    @autoreleasepool {
        LILoadPrefs();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, LIPrefsChanged, (__bridge CFStringRef)kPrefsNotify, NULL, CFNotificationSuspensionBehaviorCoalesce);
        NSString *process = [NSString stringWithUTF8String:__progname ?: ""];
        if ([process isEqualToString:@"appstored"] || [process isEqualToString:@"itunesstored"]) {
            %init(StoreHooks);
        } else if ([process isEqualToString:@"installd"]) {
            %init(InstallHooks);
        }
    }
}
