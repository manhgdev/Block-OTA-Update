#!/system/bin/sh
MODDIR="/data/adb/modules/block_ota_update"
[ -f "$MODDIR/common.sh" ] || exit 1
. "$MODDIR/common.sh"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 15

logi "Boot completed; evaluating safe OTA rules"
apply_boot_rules
logi "Boot OTA rule evaluation finished"

# Google Play services owns these components and can update itself after boot.
# Re-check only the narrow Pixel allowlist; this never disables GMS, Settings,
# the update engine service, or any package selected by a name scan.
detect_device
[ "$VENDOR" = "google" ] || exit 0
while :; do
  sleep 300
  apply_boot_rules true
done
