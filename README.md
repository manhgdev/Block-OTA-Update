# Block OTA Update

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

## Compatibility
- Android 5.0 (Lollipop) - API 21
- Android 6.0 (Marshmallow) - API 23
- Android 7.0 (Nougat) - API 24-25
- Android 8.0 (Oreo) - API 26-27
- Android 9.0 (Pie) - API 28
- Android 10 (Q) - API 29
- Android 11 (R) - API 30
- Android 12 (S) - API 31-32
- Android 13 (Tiramisu) - API 33
- Android 14 (Upside Down Cake) - API 34
- Android 15 (Vanilla Ice Cream) - API 35
- Android 16 (Baklava) - API 36
- Android 17 (Custard) - API 37

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
Edit only `update.json`:
```json
{
  "version": "v4",
  "versionCode": 4,
  "zipUrl": "https://github.com/manhgdev/Block-OTA-Update/releases/latest/download/Block-OTA-Update.zip",
  "changelog": "https://raw.githubusercontent.com/manhgdev/Block-OTA-Update/main/CHANGELOG.md"
}
```

Run the GitHub `Release` workflow to build and publish the module ZIP.
