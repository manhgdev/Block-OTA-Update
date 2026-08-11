# Block OTA Update

Safe Android OTA blocker for Magisk, KernelSU, and APatch.

Version 7.1 uses a narrow Google Pixel rule set. After Android finishes booting,
it installs one Android Intent Firewall rule for the exact **System update**
action and its known Pixel handler. Pressing **System update** is denied before
that activity can load or start an OTA flow. The Settings item may remain
visible; this is intentional, because hiding a Settings page is not proof that
OTA is blocked.

The module also disables only declared background Google Play services OTA
components for user 0, and disables com.google.android.systemupdate only when
that package is installed. It does not disable Google Play services, Settings,
update_engine, or unrelated system packages.

## Pixel behavior

On every Google Pixel, the module runs its safe OTA rule set after boot. Its
manual-flow rule is limited to `android.settings.SYSTEM_UPDATE_SETTINGS` and
`com.google.android.gms/.update.SystemUpdateActivity`. The Android framework
denies that activity launch, so selecting **System update** shows an error or
does not open the update page; it does not pretend that a new update is absent.

The module keeps the known GMS/GSF background system-update components and the
installed system-update package as narrow background-flow safeguards. If an
older module release had disabled the manual activity, v7.1 re-enables only
that module-recorded component after its firewall rule is active.

It also resolves Android's SYSTEM_UPDATE_SETTINGS action at boot. Only a
dedicated SystemUpdate component returned by that action is disabled; a generic
Settings component is logged and skipped.

Missing components are skipped and written to the log. The module never guesses
or disables a package merely because its name contains "update".

Google Play services may update itself after boot. v7.1 therefore re-checks only
the explicit Pixel OTA component allowlist every five minutes. Already-disabled
or absent targets produce no recurring log noise. It does not scan packages or
disable GMS, Settings, update_engine, or network access.

Magisk/KernelSU installers must reboot before a module service can safely use
Android's Package Manager and Intent Firewall directory. Reboot after
installation. To enforce immediately from a working rooted Android session,
run `su -c blockota enforce`.

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
those recorded entries; it never bulk-enables current targets. It also deletes
only its own `/data/system/ifw/block_ota_update.xml` rule and refuses to touch
a rule at that path without the module ownership marker.

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

When Magisk sees that marker it does not run the module scripts, so also remove
the module-owned manual-update rule from recovery if you need System Update
available immediately:

~~~sh
rm -f /data/system/ifw/block_ota_update.xml
~~~

Remove the marker after recovery to enable the module again. From a booted
system, prefer `su -c blockota restore`, which performs both operations safely.

## GitHub release

Starting with v7.1, release versions increase by 0.1: `v7.1`, `v7.2`, …,
`v7.9`, `v8.0`. The source version and tag must match exactly. `versionCode`
is `major * 10 + minor`, so v7.1 is 71, v7.9 is 79, and v8.0 is 80.

~~~sh
git add .
git commit -m "Release v7.1"
git push origin main
git tag v7.1
git push origin v7.1
~~~

Pushing the tag starts the GitHub Release workflow. It validates the metadata,
builds Block-OTA-Update.zip, tests the archive, and publishes that ZIP as the
release asset.
