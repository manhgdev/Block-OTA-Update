#!/system/bin/sh
MODDIR="/data/adb/modules/block_ota_ultimate"
LOG="/data/local/tmp/block_ota_ultimate.log"
STATE_DIR="/data/adb/block_ota_ultimate"
DISABLED_LIST="$STATE_DIR/disabled_packages.txt"
BACKUP_LIST="$STATE_DIR/package_state_backup.txt"
REPORT_JSON="$STATE_DIR/report.json"
REPORT_HTML="/sdcard/BlockOTA/report.html"
SMART_SCAN_LIST="$STATE_DIR/smart_scan_targets.txt"
TOGGLE_DIR="/sdcard/BlockOTA"
DISABLE_FILE="$TOGGLE_DIR/disable"
ENABLE_FILE="$TOGGLE_DIR/enable"
DRYRUN_FILE="$TOGGLE_DIR/dryrun"
AGGRESSIVE_FILE="$TOGGLE_DIR/aggressive"
WATCHDOG_FILE="$TOGGLE_DIR/watchdog"
PIXEL_STRICT_FILE="$TOGGLE_DIR/pixel_strict"
SMART_BLOCK_FILE="$TOGGLE_DIR/smart_block"
USER_WHITELIST="$TOGGLE_DIR/whitelist.txt"
USER_BLACKLIST="$TOGGLE_DIR/blacklist.txt"
mkdir -p "$STATE_DIR" "$TOGGLE_DIR"
[ -f "$USER_WHITELIST" ] || cat > "$USER_WHITELIST" <<EOF
# One package per line. Packages here will never be disabled.
# Example: com.google.android.gms
EOF
[ -f "$USER_BLACKLIST" ] || cat > "$USER_BLACKLIST" <<EOF
# One package per line. Packages here will always be targeted if installed.
# Example: com.vendor.ota
EOF
logi(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
lower(){ echo "$1" | tr '[:upper:]' '[:lower:]'; }
prop(){ getprop "$1" 2>/dev/null; }
detect_device(){
  BRAND="$(lower "$(prop ro.product.brand)")"; MANUFACTURER="$(lower "$(prop ro.product.manufacturer)")"; DEVICE="$(lower "$(prop ro.product.device)")"; MODEL="$(lower "$(prop ro.product.model)")"; FINGERPRINT="$(lower "$(prop ro.build.fingerprint)")"; ROM="$(lower "$(prop ro.build.version.incremental)")"; SDK="$(prop ro.build.version.sdk)"; RELEASE="$(prop ro.build.version.release)"; SLOT="$(prop ro.boot.slot_suffix)"; AB_OTA="$(prop ro.build.ab_update)"; ID="$BRAND $MANUFACTURER $DEVICE $MODEL $FINGERPRINT $ROM"; VENDOR="generic"
  echo "$ID"|grep -qiE "google|pixel"&&VENDOR="google"; echo "$ID"|grep -qiE "samsung|oneui"&&VENDOR="samsung"; echo "$ID"|grep -qiE "xiaomi|redmi|poco|miui|hyperos"&&VENDOR="xiaomi"; echo "$ID"|grep -qiE "oppo|realme|oneplus|coloros|oxygen"&&VENDOR="oppo"; echo "$ID"|grep -qiE "vivo|iqoo|bbk"&&VENDOR="vivo"; echo "$ID"|grep -qiE "huawei|honor|emui|harmony"&&VENDOR="huawei"; echo "$ID"|grep -qiE "motorola|moto|lenovo"&&VENDOR="motorola"; echo "$ID"|grep -qiE "sony|xperia"&&VENDOR="sony"; echo "$ID"|grep -qiE "asus|rog"&&VENDOR="asus"; echo "$ID"|grep -qiE "nothing"&&VENDOR="nothing"; echo "$ID"|grep -qiE "nokia|hmd"&&VENDOR="nokia"; echo "$ID"|grep -qiE "lge|lg"&&VENDOR="lg"
}
is_user_whitelisted(){ [ -f "$USER_WHITELIST" ] || return 1; grep -v '^[[:space:]]*#' "$USER_WHITELIST"|sed '/^[[:space:]]*$/d'|grep -qx "$1"; }
is_protected_pkg(){ is_user_whitelisted "$1"&&return 0; case "$1" in android|com.android.systemui|com.android.settings|com.android.packageinstaller|com.android.providers.settings|com.android.providers.downloads|com.google.android.gms) return 0;; esac; return 1; }
base_targets(){
  COMMON="com.google.android.gms.update com.android.dynsystem com.google.android.modulemetadata com.google.android.gms/.update.SystemUpdateService com.google.android.gms/.update.SystemUpdateService\$ActiveReceiver com.google.android.gms/.update.SystemUpdateActivity com.google.android.gms/.chimera.GmsIntentOperationService"
  case "$VENDOR" in
    google) VENDOR_PKGS="com.google.android.systemupdate com.google.android.apps.work.oobconfig";;
    samsung) VENDOR_PKGS="com.wssyncmldm com.sec.android.soagent com.sec.android.fotaclient com.samsung.sdm com.samsung.sdm.sdmviewer com.samsung.android.lool";;
    xiaomi) VENDOR_PKGS="com.android.updater com.miui.rom com.miui.cloudbackup com.miui.msa.global com.xiaomi.discover";;
    oppo) VENDOR_PKGS="com.coloros.sau com.oplus.ota com.oplus.sau com.oplus.romupdate com.oneplus.opbackup";;
    vivo) VENDOR_PKGS="com.bbk.updater com.vivo.upslide com.vivo.daemonService";;
    huawei) VENDOR_PKGS="com.huawei.android.hwouc com.huawei.android.hwouc.overlay com.huawei.hwid";;
    motorola) VENDOR_PKGS="com.motorola.ccc.ota com.motorola.ccc.devicemanagement com.motorola.android.fota";;
    sony) VENDOR_PKGS="com.sonyericsson.updatecenter com.sonymobile.updatecenter";;
    asus) VENDOR_PKGS="com.asus.dm com.asus.systemupdate com.asus.updatecenter";;
    nothing) VENDOR_PKGS="com.nothing.ota com.nothing.systemupdate";;
    nokia) VENDOR_PKGS="com.evenwell.ota com.evenwell.otaservice com.hmdglobal.app.update";;
    lg) VENDOR_PKGS="com.lge.lgfota.permission com.lge.lgdmsclient com.lge.updatecenter";;
    *) VENDOR_PKGS="com.android.updater";;
  esac
  echo "$COMMON $VENDOR_PKGS"
}
pixel_strict_targets(){ detect_device; [ "$VENDOR" = "google" ] || return; [ -f "$PIXEL_STRICT_FILE" ] || return; echo "com.google.android.gms/.update.SystemUpdateService com.google.android.gms/.update.SystemUpdateActivity com.google.android.gms/.update.SystemUpdateService\$ActiveReceiver com.google.android.gms/.update.SystemUpdateGcmTaskService com.google.android.apps.work.oobconfig com.android.dynsystem com.google.android.modulemetadata"; }
aggressive_targets(){ [ -f "$AGGRESSIVE_FILE" ] || return; echo "com.android.updater com.google.android.partnersetup com.google.android.configupdater com.android.localtransport"; }
user_blacklist_targets(){ [ -f "$USER_BLACKLIST" ] || return; grep -v '^[[:space:]]*#' "$USER_BLACKLIST"|sed '/^[[:space:]]*$/d'; }
smart_scan_targets(){ [ -f "$SMART_BLOCK_FILE" ] || return; [ -f "$SMART_SCAN_LIST" ] && cat "$SMART_SCAN_LIST"; }
packages_for_vendor(){ detect_device; { base_targets; pixel_strict_targets; aggressive_targets; user_blacklist_targets; smart_scan_targets; }|tr ' ' '\n'|sed '/^[[:space:]]*$/d'|sort -u; }
pkg_exists(){ pm path "$1" >/dev/null 2>&1; }
record_disabled(){ grep -qx "$1" "$DISABLED_LIST" 2>/dev/null || echo "$1" >> "$DISABLED_LIST"; }
backup_state(){ [ -f "$BACKUP_LIST" ]&&return; for p in $(packages_for_vendor); do echo "$p"|grep -q "/"&&continue; pkg_exists "$p"||continue; state="$(pm list packages -d 2>/dev/null|grep -q "package:$p"&&echo disabled||echo enabled)"; echo "$p $state" >> "$BACKUP_LIST"; done; logi "Backup state saved"; }
disable_component(){ c="$1"; [ -f "$DRYRUN_FILE" ]&&{ logi "[DRYRUN] Would disable component: $c"; return; }; cmd package set-enabled-setting "$c" disabled-user 0 >/dev/null 2>&1&&logi "Disabled component: $c"; }
disable_pkg(){ p="$1"; echo "$p"|grep -q "/"&&{ disable_component "$p"; return; }; pkg_exists "$p"||return; if is_protected_pkg "$p"; then logi "Skip protected/whitelisted package: $p"; return; fi; [ -f "$DRYRUN_FILE" ]&&{ logi "[DRYRUN] Would disable package: $p"; return; }; for user in $(cmd user list 2>/dev/null|grep -oE '\{[0-9]+'|tr -d '{'); do pm disable-user --user "$user" "$p" >/dev/null 2>&1&&{ logi "Disabled package user=$user: $p"; record_disabled "$p"; }; pm hide "$p" >/dev/null 2>&1&&logi "Hidden package: $p"; done; pm disable "$p" >/dev/null 2>&1&&{ logi "Disabled package globally: $p"; record_disabled "$p"; }; }
restore_pkg(){ p="$1"; echo "$p"|grep -q "/"&&{ cmd package set-enabled-setting "$p" default 0 >/dev/null 2>&1; logi "Restored component: $p"; return; }; for user in $(cmd user list 2>/dev/null|grep -oE '\{[0-9]+'|tr -d '{'); do pm enable --user "$user" "$p" >/dev/null 2>&1&&logi "Enabled user=$user: $p"; pm unhide "$p" >/dev/null 2>&1; done; pm enable "$p" >/dev/null 2>&1&&logi "Enabled globally: $p"; }
block_jobs(){ for p in $(packages_for_vendor); do echo "$p"|grep -q "/"&&continue; pkg_exists "$p"||continue; cmd jobscheduler cancel "$p" 0 >/dev/null 2>&1; cmd jobscheduler cancel -u 0 "$p" 0 >/dev/null 2>&1; done; logi "Best-effort updater jobs cancelled"; }
block_settings(){ settings put global ota_disable_automatic_update 1 2>/dev/null; settings put global update_engine_disable 1 2>/dev/null; settings put global automatic_system_updates 0 2>/dev/null; settings put secure automatic_storage_manager_enabled 0 2>/dev/null; logi "Applied OTA-related settings"; }
clean_ota_files(){ for d in /data/ota_package /data/system_updates /data/update_engine /data/ota /data/fota /data/cache /cache/recovery /cache/fota /cache/ota /metadata/ota /sdcard/Download /sdcard/OTA /sdcard/.OTA; do [ -d "$d" ]||continue; find "$d" -maxdepth 4 -type f \( -iname "*ota*.zip" -o -iname "*update*.zip" -o -iname "*firmware*.zip" -o -iname "payload.bin" -o -iname "*.payload" -o -iname "care_map.pb" -o -iname "metadata.pb" -o -iname "compatibility.zip" \) -delete 2>/dev/null; logi "Cleaned OTA payloads in: $d"; done; }
scan_ota_packages(){ echo "Installed packages matching OTA/update keywords:"; pm list packages 2>/dev/null|cut -d: -f2|grep -iE "ota|fota|update|updater|systemupdate|fotaclient|soagent|wssync|hwouc|sau|romupdate|dmclient|device.*management"|sort; }
scan_smart(){ pm list packages 2>/dev/null|cut -d: -f2|grep -iE "ota|fota|systemupdate|fotaclient|soagent|wssync|hwouc|romupdate|updater|updatecenter|dmclient|device.*management|ccc.ota|sau"|sort > "$SMART_SCAN_LIST"; logi "Smart scan saved: $SMART_SCAN_LIST"; cat "$SMART_SCAN_LIST"; }
health_check(){ detect_device; failed=""; ok=""; for p in $(packages_for_vendor); do echo "$p"|grep -q "/"&&continue; pkg_exists "$p"||continue; if pm list packages -d 2>/dev/null|grep -q "package:$p"; then ok="$ok $p"; else if is_protected_pkg "$p"; then ok="$ok $p(protected)"; else failed="$failed $p"; fi; fi; done; logi "Health ok:$ok"; [ -n "$failed" ]&&logi "Health still enabled:$failed"; }
write_json_report(){ detect_device; active=true; [ -f "$DISABLE_FILE" ]&&active=false; aggressive=false; [ -f "$AGGRESSIVE_FILE" ]&&aggressive=true; dryrun=false; [ -f "$DRYRUN_FILE" ]&&dryrun=true; watchdog=false; [ -f "$WATCHDOG_FILE" ]&&watchdog=true; pixel_strict=false; [ -f "$PIXEL_STRICT_FILE" ]&&pixel_strict=true; smart_block=false; [ -f "$SMART_BLOCK_FILE" ]&&smart_block=true; disabled_count=0; [ -f "$DISABLED_LIST" ]&&disabled_count="$(wc -l < "$DISABLED_LIST"|tr -d ' ')"; smart_count=0; [ -f "$SMART_SCAN_LIST" ]&&smart_count="$(wc -l < "$SMART_SCAN_LIST"|tr -d ' ')"; cat > "$REPORT_JSON" <<EOF
{"module":"Block OTA Ultimate","version":"6.0","versionCode":6,"active":$active,"aggressive":$aggressive,"dryrun":$dryrun,"watchdog":$watchdog,"pixel_strict":$pixel_strict,"smart_block":$smart_block,"vendor":"$VENDOR","brand":"$BRAND","manufacturer":"$MANUFACTURER","model":"$MODEL","device":"$DEVICE","android_release":"$RELEASE","sdk":"$SDK","ab_ota":"$AB_OTA","slot":"$SLOT","disabled_record_count":$disabled_count,"smart_scan_count":$smart_count,"log":"$LOG"}
EOF
}
write_html_report(){ write_json_report; cat > "$REPORT_HTML" <<EOF
<!doctype html><html><head><meta charset="utf-8"><title>Block OTA Ultimate v6</title><style>body{font-family:Arial;background:#111;color:#eee;padding:20px}.card{background:#1d1d1d;border-radius:12px;padding:16px;margin:12px 0}.ok{color:#6ee77a}.warn{color:#ffd166}pre{white-space:pre-wrap;background:#0b0b0b;padding:12px;border-radius:8px}</style></head><body><h1>Block OTA Ultimate v6</h1><div class="card"><b>Vendor:</b> $VENDOR<br><b>Brand:</b> $BRAND<br><b>Manufacturer:</b> $MANUFACTURER<br><b>Model:</b> $MODEL<br><b>Android:</b> $RELEASE / SDK $SDK<br><b>A/B OTA:</b> $AB_OTA</div><div class="card"><b>Status:</b> $( [ -f "$DISABLE_FILE" ] && echo '<span class="warn">PAUSED</span>' || echo '<span class="ok">ACTIVE</span>' )<br><b>Aggressive:</b> $( [ -f "$AGGRESSIVE_FILE" ]&&echo yes||echo no )<br><b>Pixel strict:</b> $( [ -f "$PIXEL_STRICT_FILE" ]&&echo yes||echo no )<br><b>Watchdog:</b> $( [ -f "$WATCHDOG_FILE" ]&&echo yes||echo no )<br><b>Smart block:</b> $( [ -f "$SMART_BLOCK_FILE" ]&&echo yes||echo no )</div><div class="card"><h2>Disabled records</h2><pre>$( [ -f "$DISABLED_LIST" ]&&cat "$DISABLED_LIST"||echo none )</pre></div><div class="card"><h2>Smart scan targets</h2><pre>$( [ -f "$SMART_SCAN_LIST" ]&&cat "$SMART_SCAN_LIST"||echo none )</pre></div><div class="card"><h2>Log tail</h2><pre>$( tail -n 80 "$LOG" 2>/dev/null )</pre></div></body></html>
EOF
echo "$REPORT_HTML"; }
github_help(){ cat <<EOF
GitHub update setup:
1) Create repo: https://github.com/manhgdev/Block-OTA-Ultimate
2) Upload: Block_OTA_Ultimate_v6.zip, update.json, README.md, CHANGELOG.md
3) Create Release tag: v6.0
4) Edit module.prop updateJson raw URL
5) Edit update.json zipUrl to release asset URL
EOF
}
status_report(){ detect_device; write_json_report; echo "Block OTA Ultimate v6"; echo "Vendor: $VENDOR"; echo "Brand: $BRAND"; echo "Manufacturer: $MANUFACTURER"; echo "Model: $MODEL"; echo "Android: $RELEASE / SDK $SDK"; echo "A/B OTA: $AB_OTA Slot: $SLOT"; [ -f "$DISABLE_FILE" ]&&echo "Status: PAUSED"||echo "Status: ACTIVE"; [ -f "$AGGRESSIVE_FILE" ]&&echo "Mode: AGGRESSIVE"||echo "Mode: SAFE"; [ -f "$PIXEL_STRICT_FILE" ]&&echo "Pixel strict: ON"||echo "Pixel strict: OFF"; [ -f "$WATCHDOG_FILE" ]&&echo "Watchdog: ON"||echo "Watchdog: OFF"; [ -f "$SMART_BLOCK_FILE" ]&&echo "Smart block: ON"||echo "Smart block: OFF"; [ -f "$DRYRUN_FILE" ]&&echo "Dry-run: ON"||echo "Dry-run: OFF"; echo "JSON report: $REPORT_JSON"; echo "HTML report: $REPORT_HTML"; tail -n 30 "$LOG" 2>/dev/null; }
block_all(){ [ -f "$DISABLE_FILE" ]&&{ logi "Paused: $DISABLE_FILE exists"; write_json_report; exit 0; }; detect_device; backup_state; logi "Detected vendor=$VENDOR brand=$BRAND manufacturer=$MANUFACTURER model=$MODEL android=$RELEASE sdk=$SDK ab=$AB_OTA"; block_settings; for p in $(packages_for_vendor); do disable_pkg "$p"; done; block_jobs; clean_ota_files; health_check; write_json_report; logi "Block cycle complete"; }
restore_all(){ logi "Restoring disabled OTA packages/components"; if [ -f "$DISABLED_LIST" ]; then while read -r p; do [ -n "$p" ]&&restore_pkg "$p"; done < "$DISABLED_LIST"; fi; for p in $(packages_for_vendor); do restore_pkg "$p"; done; rm -f "$DISABLED_LIST"; write_json_report; logi "Restore complete"; }
