#!/system/bin/sh
MODDIR="${0%/*}"
sleep 45
. "$MODDIR/common.sh"
logi "service started"
while true; do
  if [ -f "$ENABLE_FILE" ]; then rm -f "$ENABLE_FILE" "$DISABLE_FILE"; restore_all; logi "Manual restore requested"; else block_all; fi
  if [ -f "$WATCHDOG_FILE" ]; then sleep 600; else sleep 1800; fi
done
