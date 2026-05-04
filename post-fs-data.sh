#!/system/bin/sh
MODDIR="${0%/*}"
. "$MODDIR/common.sh"
logi "post-fs-data started"
block_all
