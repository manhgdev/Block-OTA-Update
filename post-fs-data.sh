#!/system/bin/sh
MODDIR="/data/adb/modules/block_ota_update"
LOG="/data/local/tmp/block_ota_update.log"

(
  sleep 15
  echo "[$(date)] post-fs-data started" >> "$LOG"
  pm disable com.google.android.gms/.update.SystemUpdateService 2>/dev/null && \
  echo "[$(date)] Disabled SystemUpdateService" >> "$LOG"
  mount -o bind "$MODDIR/system/etc/hosts" /system/etc/hosts && \
  echo "[$(date)] Hosts mounted - OTA URLs blocked" >> "$LOG"
) &
