# Changelog

## v7
- Fixed Pixel component enforcement: Android component targets now use `pm disable --user 0`, which produces an actual disabled component state on Pixel 7 Android 13.
- Replaced the in-memory GMS package-dump cache, which exceeded Android's shell argument limit, with small per-process dump files read by `grep` and `awk`.
- Verified on a connected Pixel 7 Android 13: the resolved `com.google.android.gms/.update.SystemUpdateActivity` is disabled and the standard System Update intent no longer resolves.

## v6
- Added narrow, explicit Pixel OTA components that handle persistent update listening, OTA suggestions, and update popups; unavailable components are skipped.
- Added legacy Google Services Framework OTA components when present, still as user-0 component-only changes.
- Re-checks only that fixed allowlist every five minutes after boot so a Google Play services update cannot silently re-enable an OTA entry point.
- Added `blockota enforce` for an immediate safe enforcement pass from a booted rooted Android session. Module installation itself still requires a reboot before Package Manager changes are made.

## v5
- Resolve Android's SYSTEM_UPDATE_SETTINGS action at boot and disable its handler only when it is a dedicated, allowlisted SystemUpdate component.
- Added blockota resolve and health reporting for the resolved system-update activity.

## v4
- Added a safe Google Pixel boot rule set that runs only after Android boot completes.
- Limited Pixel changes to explicit GMS OTA components and com.google.android.systemupdate for user 0.
- Removed broad Google/system package targets, hosts overrides, update-engine controls, network blocking, payload deletion, and aggressive mode.
- Restore now re-enables only changes recorded by v4; it does not bulk-enable packages.
- Release workflow now validates source metadata against the pushed tag before building the ZIP.

## v2
- Added GitHub update channel template.
- Added `github-help`.
- Added smart scan and smart block.
- Added watchdog mode.
- Added Pixel strict mode.
- Added HTML report.
- Improved JSON report.
- Improved safe package protection.
