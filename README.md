# LowerInstall 16 (Dopamine / rootless)

Experimental iOS 16 rootless update of Julio Verne's LowerInstall.

## Changes
- Rootless Theos package scheme.
- arm64 + arm64e builds.
- Injects only into `appstored`, `itunesstored`, and `installd`.
- Removes legacy LaunchDaemon plist reload logic.
- Keeps App Store User-Agent spoofing.
- Narrows MobileInstallation hooks to OS/device compatibility checks; signing/identifier validation is not bypassed.
- Validates the spoofed iOS version string before applying it.

## Build
Requires Theos with a compatible iOS SDK:

```sh
export THEOS=/path/to/theos
make clean package FINALPACKAGE=1
```

The resulting `.deb` will be placed in `packages/`.

## Important
This can bypass version metadata checks. It cannot provide frameworks/APIs that an app truly requires from a newer iOS release. Start with a plausible spoof version and disable the tweak after purchasing/downloading the app if needed.
