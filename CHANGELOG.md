# Changelog

## v7.3
- Removes only `/data/ota_package/metadata.pb` and `/data/ota_package/payload_metadata.bin` after the Pixel IFW rule is active.
- Skips metadata cleanup whenever `/metadata/ota/snapshots` contains an entry, avoiding changes while Android has an OTA snapshot in progress.
- Adds health output for OTA snapshot and metadata presence. No update process, partition, snapshot, Google Play services data, or update-engine preferences are stopped or deleted.

## v7.2
- Added the exact Pixel OTA nag component `com.google.android.gms/.update.phone.PopupDialog` to the module-owned Intent Firewall rule. This blocks the full-screen **Download and install now** popup shown over the launcher even when Package Manager does not expose that component for `pm disable`.
- Added its observed `android.settings.SYSTEM_UPDATE_COMPLETE` action as a second exact match for the same activity rule.
- Added action-only service rules for the two OTA intents observed on Pixel 7 Android 13: `com.google.android.gms.update.INSTALL_UPDATE` and `com.google.android.gms.update.RESUME_ON_REBOOOT_LSKF_CAPTURED`. They block those OTA operations without blocking the shared `GmsIntentOperationService` component.
- Kept the existing manual System Update action/activity block and narrow background component safeguards unchanged.
- The v7.1 ownership marker is preserved so upgrades atomically replace the existing module rule; restore and uninstall still remove only that one owned XML file.

## v7.1
- Added one Android Intent Firewall rule for the exact manual Pixel System Update action and its resolved Google Play services activity. Pressing **System update** is denied before that activity can fetch or start an OTA flow.
- The rule is owned by the module, installed only after boot, written atomically with `system:system` ownership, and never replaces or removes a foreign Intent Firewall rule.
- `blockota restore`, normal uninstall, and the paused runtime path remove only that module-owned rule. Recovery instructions now include the exact rule path when using the module `disable` marker.
- Kept the narrow component allowlist as a secondary background-OTA safeguard, but releases the legacy module-owned manual activity disable after the firewall rule is active so the user receives a denied launch instead of a hidden item. No broad Google Play services, Settings, network, update-service, or data changes were added.

## v7
- Fixed Pixel component enforcement: Android component targets now use `pm disable --user 0`, which produces an actual disabled component state on Pixel 7 Android 13.
- Replaced the in-memory GMS package-dump cache, which exceeded Android's shell argument limit, with small per-process dump files read by `grep` and `awk`.
- Verified on a connected Pixel 7 Android 13 that the resolved `com.google.android.gms/.update.SystemUpdateActivity` enters the disabled component state.

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
