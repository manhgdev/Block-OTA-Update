# Block OTA Update

Safe Android OTA blocker for Magisk, KernelSU, and APatch.

Version 4 uses a narrow Google Pixel rule set: it runs after Android finishes
booting, disables only declared Google Play services OTA components for user 0,
and disables com.google.android.systemupdate only when that package is installed.
It does not disable Google Play services, Settings, update_engine, or unrelated
system packages.

## Pixel behavior

On every Google Pixel, the module runs its safe OTA rule set after boot. It
blocks the known GMS system-update entry points and the installed system-update
package, so both background and manual OTA flows are blocked.

Missing components are skipped and written to the log. The module never guesses
or disables a package merely because its name contains "update".

Other vendors are changed only when you run the explicit block command.

## Commands

~~~sh
su -c blockota status
su -c blockota health
su -c blockota block
su -c blockota restore
su -c blockota pause
su -c blockota resume
su -c blockota scan
su -c blockota scan-smart
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

If you need to turn off the module from recovery or a root shell before Android
starts, create this Magisk-compatible marker:

~~~sh
touch /data/adb/modules/block_ota_update/disable
~~~

Remove that marker after recovery to enable the module again.

## GitHub release

The source version and tag must match exactly. For v4, module.prop and
update.json both use version v4 and versionCode 4.

~~~sh
git add .
git commit -m "Release v4"
git push origin main
git tag v4
git push origin v4
~~~

Pushing the tag starts the GitHub Release workflow. It validates the metadata,
builds Block-OTA-Update.zip, tests the archive, and publishes that ZIP as the
release asset.
