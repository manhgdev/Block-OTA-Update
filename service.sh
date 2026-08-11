#!/system/bin/sh
MODDIR="/data/adb/modules/block_ota_update"
[ -f "$MODDIR/common.sh" ] || exit 1
. "$MODDIR/common.sh"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 15

logi "Boot completed; evaluating safe OTA rules"
apply_boot_rules
logi "Boot OTA rule evaluation finished"
