#!/system/bin/sh
MODDIR="/data/adb/modules/block_ota_ultimate"
[ -f "$MODDIR/common.sh" ] && { . "$MODDIR/common.sh"; restore_all; }
