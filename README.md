# Block OTA Ultimate v6

Universal Android OTA blocker for Magisk / KernelSU / APatch.

## Features
- Auto-detect Android vendor.
- Block OTA packages/components.
- Clean downloaded OTA payloads.
- Safe mode by default.
- Optional aggressive mode.
- Optional Pixel strict mode.
- Optional smart scan + smart block.
- Optional watchdog mode.
- JSON and HTML report.
- GitHub update channel support.

## Commands
```sh
su -c blockota status
su -c blockota scan-smart
su -c blockota smart-block-on
su -c blockota pixel-strict-on
su -c blockota aggressive-on
su -c blockota watchdog-on
su -c blockota report
su -c blockota github-help
```

## GitHub Update
Edit `module.prop`:
```ini
updateJson=https://raw.githubusercontent.com/manhgdev/Block-OTA-Ultimate/main/update.json
```
Edit `update.json` after creating a GitHub Release.
