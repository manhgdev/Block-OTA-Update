#!/system/bin/sh
LOG="/data/local/tmp/block_ota_update.log"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 30

echo "[$(date)] service started" >> "$LOG"
pm disable com.google.android.gms/.update.SystemUpdateService 2>/dev/null
echo "[$(date)] OTA blocked" >> "$LOG"
