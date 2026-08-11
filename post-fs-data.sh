#!/system/bin/sh
LOG="/data/local/tmp/block_ota_update.log"

# Package Manager is not reliable at post-fs-data time on Android 13. The
# service script waits for boot completion before applying the safe rules.
echo "[$(date)] post-fs-data complete; OTA package rules deferred until boot" >> "$LOG"
