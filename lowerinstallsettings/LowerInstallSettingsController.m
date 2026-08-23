#import "LowerInstallSettingsController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <sys/utsname.h>

static NSString * const kPrefsPath = @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist";
static const char *kPrefsNotify = "com.julioverne.lowerinstall/SettingsChanged";

@implementation LowerInstallSettingsController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    struct utsname info;
    uname(&info);
    NSString *device = [NSString stringWithUTF8String:info.machine] ?: @"iPhone";
    NSString *version = UIDevice.currentDevice.systemVersion ?: @"16.0";

    NSMutableArray *items = [NSMutableArray array];
    PSSpecifier *s;

    s = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [s setProperty:@"Enabled" forKey:@"key"];
    [s setProperty:@YES forKey:@"default"];
    [items addObject:s];

    s = [PSSpecifier groupSpecifierWithName:@"Spoof"];
    [s setProperty:@"Use a plausible iOS version. Spoofing only bypasses compatibility checks; it cannot add frameworks or APIs that an app actually requires." forKey:@"footerText"];
    [items addObject:s];

    s = [PSSpecifier preferenceSpecifierNamed:@"iOS Version" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
    [s setProperty:@"SpoofVersion" forKey:@"key"];
    [s setProperty:version forKey:@"default"];
    [items addObject:s];

    s = [PSSpecifier preferenceSpecifierNamed:@"Device" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
    [s setProperty:@"SpoofDevice" forKey:@"key"];
    [s setProperty:device forKey:@"default"];
    [items addObject:s];

    s = [PSSpecifier groupSpecifierWithName:@"Actions"];
    [items addObject:s];

    s = [PSSpecifier preferenceSpecifierNamed:@"Reset Settings" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    s->action = @selector(resetSettings);
    [items addObject:s];

    _specifiers = [items copy];
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: @{};
    NSString *key = [specifier propertyForKey:@"key"];
    return (key ? prefs[key] : nil) ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: [NSMutableDictionary dictionary];
    NSString *key = [specifier propertyForKey:@"key"];
    if (key && value) prefs[key] = value;
    [prefs writeToFile:kPrefsPath atomically:YES];
    notify_post(kPrefsNotify);
}

- (void)resetSettings {
    [[NSFileManager defaultManager] removeItemAtPath:kPrefsPath error:nil];
    notify_post(kPrefsNotify);
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"LowerInstall" message:@"Settings reset. Restart App Store before testing again." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
