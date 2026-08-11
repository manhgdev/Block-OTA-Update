# Changelog

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
