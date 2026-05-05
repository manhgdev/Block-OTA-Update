#!/system/bin/sh
MODDIR="/data/adb/modules/block_ota_update"
[ -f "$MODDIR/common.sh" ] && { . "$MODDIR/common.sh"; restore_all; }
