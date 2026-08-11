# Block OTA Update

Safe Android OTA blocker for Magisk, KernelSU, and APatch.

Version 7 uses a narrow Google Pixel rule set: it runs after Android finishes
booting, disables only declared Google Play services OTA components for user 0,
and disables com.google.android.systemupdate only when that package is installed.
It does not disable Google Play services, Settings, update_engine, or unrelated
system packages.

## Pixel behavior

On every Google Pixel, the module runs its safe OTA rule set after boot. It
blocks the known GMS/GSF system-update entry points and the installed
system-update package, so both background and manual OTA flows are blocked.

It also resolves Android's SYSTEM_UPDATE_SETTINGS action at boot. Only a
dedicated SystemUpdate component returned by that action is disabled; a generic
Settings component is logged and skipped.

Missing components are skipped and written to the log. The module never guesses
or disables a package merely because its name contains "update".

Google Play services may update itself after boot. v7 therefore re-checks only
the explicit Pixel OTA component allowlist every five minutes. Already-disabled
or absent targets produce no recurring log noise. It does not scan packages or
disable GMS, Settings, update_engine, or network access.

Magisk/KernelSU installers must reboot before a module service can safely use
Android's Package Manager. Reboot after installation. To enforce immediately
from a working rooted Android session, run `su -c blockota enforce`.

Other vendors are changed only when you run the explicit block command.

## Commands

~~~sh
su -c blockota status
su -c blockota health
su -c blockota block
su -c blockota enforce
su -c blockota restore
su -c blockota pause
su -c blockota resume
su -c blockota scan
su -c blockota scan-smart
su -c blockota resolve
su -c blockota smart-block-on
su -c blockota smart-block-off
su -c blockota report
su -c blockota log
~~~

Smart Block is manual only. It may target packages based on their names, so
review its log before rebooting. It is never run automatically at boot.

## Safety and recovery

The module records only changes it makes in
/data/adb/block_ota_update/applied_v4.txt. The restore command re-enables only
those recorded entries; it never bulk-enables current targets.

If Android still boots:

~~~sh
su -c blockota restore
~~~

`restore` also pauses the module, so its five-minute Pixel re-check cannot
immediately apply the rules again. Use `su -c blockota resume` when ready.

If you need to turn off the module from recovery or a root shell before Android
starts, create this Magisk-compatible marker:

~~~sh
touch /data/adb/modules/block_ota_update/disable
~~~

Remove that marker after recovery to enable the module again.

## GitHub release

The source version and tag must match exactly. For v7, module.prop and
update.json both use version v7 and versionCode 7.

~~~sh
git add .
git commit -m "Release v7"
git push origin main
git tag v7
git push origin v7
~~~

Pushing the tag starts the GitHub Release workflow. It validates the metadata,
builds Block-OTA-Update.zip, tests the archive, and publishes that ZIP as the
release asset.
