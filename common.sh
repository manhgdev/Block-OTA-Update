#!/system/bin/sh

# Safe OTA blocking helpers.  All state-changing operations are scoped to the
# owner user (0) and recorded so that only module-owned changes are restored.
MODDIR="/data/adb/modules/block_ota_update"
LOG="/data/local/tmp/block_ota_update.log"
STATE_DIR="/data/adb/block_ota_update"
APPLIED_LIST="$STATE_DIR/applied_v4.txt"
LEGACY_DISABLED_LIST="$STATE_DIR/disabled_packages.txt"
REPORT_JSON="$STATE_DIR/report.json"
REPORT_HTML="/sdcard/BlockOTA/report.html"
SMART_SCAN_LIST="$STATE_DIR/smart_scan_targets.txt"
TOGGLE_DIR="$STATE_DIR/toggles"
DISABLE_FILE="$TOGGLE_DIR/disable"
DRYRUN_FILE="$TOGGLE_DIR/dryrun"
SMART_BLOCK_FILE="$TOGGLE_DIR/smart_block"
USER_WHITELIST="$TOGGLE_DIR/whitelist.txt"
USER_BLACKLIST="$TOGGLE_DIR/blacklist.txt"

mkdir -p "$STATE_DIR" "$TOGGLE_DIR" 2>/dev/null
[ -f "$USER_WHITELIST" ] || cat > "$USER_WHITELIST" <<EOF
# One package per line. Packages here will never be disabled.
# Example: com.google.android.gms
EOF
[ -f "$USER_BLACKLIST" ] || cat > "$USER_BLACKLIST" <<EOF
# One package per line. Packages here are only targeted by an explicit
# blockota block or smart-block-on command.
# Example: com.vendor.ota
EOF

logi(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
lower(){ echo "$1" | tr '[:upper:]' '[:lower:]'; }
prop(){ getprop "$1" 2>/dev/null; }
module_value(){ sed -n "s/^$1=//p" "$MODDIR/module.prop" 2>/dev/null | head -n 1; }

detect_device(){
  BRAND="$(lower "$(prop ro.product.brand)")"
  MANUFACTURER="$(lower "$(prop ro.product.manufacturer)")"
  DEVICE="$(lower "$(prop ro.product.device)")"
  MODEL="$(lower "$(prop ro.product.model)")"
  FINGERPRINT="$(lower "$(prop ro.build.fingerprint)")"
  ROM="$(lower "$(prop ro.build.version.incremental)")"
  SDK="$(prop ro.build.version.sdk)"
  RELEASE="$(prop ro.build.version.release)"
  SLOT="$(prop ro.boot.slot_suffix)"
  AB_OTA="$(prop ro.build.ab_update)"
  ID="$BRAND $MANUFACTURER $DEVICE $MODEL $FINGERPRINT $ROM"
  VENDOR="generic"
  echo "$ID" | grep -qiE "google|pixel" && VENDOR="google"
  echo "$ID" | grep -qiE "samsung|oneui" && VENDOR="samsung"
  echo "$ID" | grep -qiE "xiaomi|redmi|poco|miui|hyperos" && VENDOR="xiaomi"
  echo "$ID" | grep -qiE "oppo|realme|oneplus|coloros|oxygen" && VENDOR="oppo"
  echo "$ID" | grep -qiE "vivo|iqoo|bbk" && VENDOR="vivo"
  echo "$ID" | grep -qiE "huawei|honor|emui|harmony" && VENDOR="huawei"
  echo "$ID" | grep -qiE "motorola|moto|lenovo" && VENDOR="motorola"
  echo "$ID" | grep -qiE "sony|xperia" && VENDOR="sony"
  echo "$ID" | grep -qiE "asus|rog" && VENDOR="asus"
  echo "$ID" | grep -qiE "nothing" && VENDOR="nothing"
  echo "$ID" | grep -qiE "nokia|hmd" && VENDOR="nokia"
  echo "$ID" | grep -qiE "lge|lg" && VENDOR="lg"
}

is_user_whitelisted(){
  [ -f "$USER_WHITELIST" ] || return 1
  grep -v '^[[:space:]]*#' "$USER_WHITELIST" | sed '/^[[:space:]]*$/d' | grep -qx "$1"
}

is_protected_pkg(){
  is_user_whitelisted "$1" && return 0
  case "$1" in
    android|com.android.systemui|com.android.settings|com.android.packageinstaller|com.android.providers.settings|com.android.providers.downloads|com.google.android.gms)
      return 0
      ;;
  esac
  return 1
}

pkg_exists(){ pm path "$1" >/dev/null 2>&1; }

pkg_state(){
  p="$1"
  if ! pkg_exists "$p"; then
    echo "absent"
  elif pm list packages -d --user 0 2>/dev/null | grep -qx "package:$p"; then
    echo "disabled"
  else
    echo "enabled"
  fi
}

component_package(){ echo "$1" | cut -d/ -f1; }
component_full_name(){
  c="$1"
  p="$(component_package "$c")"
  short="$(echo "$c" | cut -d/ -f2-)"
  case "$short" in
    .*) echo "$p$short" ;;
    *) echo "$short" ;;
  esac
}

# Each Pixel enforcement pass touches several components in the same packages.
# Keep a per-process dump file instead of passing the large GMS dump through a
# shell argument: Android's /system/bin/printf has a small argument limit.
clear_component_dump_cache(){
  rm -f \
    "$STATE_DIR/.block_ota_gms_dump.$$" \
    "$STATE_DIR/.block_ota_gsf_dump.$$" \
    "$STATE_DIR/.block_ota_settings_dump.$$" \
    "$STATE_DIR/.block_ota_systemupdate_dump.$$"
  unset COMPONENT_DUMP_FILE
}

load_component_package_dump(){
  p="$1"
  case "$p" in
    com.google.android.gms) dump_file="$STATE_DIR/.block_ota_gms_dump.$$" ;;
    com.google.android.gsf) dump_file="$STATE_DIR/.block_ota_gsf_dump.$$" ;;
    com.android.settings) dump_file="$STATE_DIR/.block_ota_settings_dump.$$" ;;
    com.google.android.systemupdate) dump_file="$STATE_DIR/.block_ota_systemupdate_dump.$$" ;;
    *) return 1 ;;
  esac
  if [ ! -f "$dump_file" ]; then
    dumpsys package "$p" > "$dump_file" 2>/dev/null || return 1
  fi
  [ -s "$dump_file" ] || return 1
  COMPONENT_DUMP_FILE="$dump_file"
}

component_exists(){
  c="$1"
  p="$(component_package "$c")"
  full="$(component_full_name "$c")"
  pkg_exists "$p" || return 1
  load_component_package_dump "$p" || return 1
  grep -Fq "$full" "$COMPONENT_DUMP_FILE"
}

# A component is safe to change only when its state can be read from the
# primary-user package dump.  Unknown state is deliberately skipped.
component_state(){
  c="$1"
  p="$(component_package "$c")"
  full="$(component_full_name "$c")"
  load_component_package_dump "$p" || { echo "unknown"; return; }
  grep -q '^[[:space:]]*User 0:' "$COMPONENT_DUMP_FILE" || { echo "unknown"; return; }
  awk -v target="$full" '
    $1 == "User" && $2 == "0:" { in_user=1; section=""; next }
    $1 == "User" && $2 ~ /^[0-9]+:$/ && in_user { exit }
    !in_user { next }
    $0 ~ /^[[:space:]]*disabledComponents:/ { section="disabled"; next }
    $0 ~ /^[[:space:]]*enabledComponents:/ { section="enabled"; next }
    section == "disabled" && index($0, target) > 0 { found=1; exit }
    END { if (found) print "disabled"; else print "enabled" }
  ' "$COMPONENT_DUMP_FILE"
}

record_applied(){
  entry="$1|$2"
  grep -Fqx "$entry" "$APPLIED_LIST" 2>/dev/null || echo "$entry" >> "$APPLIED_LIST"
}

disable_component_safely(){
  c="$1"
  p="$(component_package "$c")"
  quiet="${2:-false}"
  [ -f "$DRYRUN_FILE" ] && { [ "$quiet" = true ] || logi "[DRYRUN] Would disable component user=0: $c"; return; }
  is_user_whitelisted "$p" && { [ "$quiet" = true ] || logi "Skip whitelisted component package: $p"; return; }
  component_exists "$c" || { [ "$quiet" = true ] || logi "Skip unavailable OTA component: $c"; return; }
  state="$(component_state "$c")"
  case "$state" in
    disabled) [ "$quiet" = true ] || logi "Component already disabled user=0: $c"; return ;;
    unknown) [ "$quiet" = true ] || logi "WARNING: State unknown; skipped component: $c"; return ;;
  esac
  if pm disable --user 0 "$c" >/dev/null 2>&1; then
    record_applied component "$c"
    logi "Disabled OTA component user=0: $c"
  else
    logi "WARNING: Could not disable OTA component: $c"
  fi
}

disable_package_safely(){
  p="$1"
  [ -f "$DRYRUN_FILE" ] && { logi "[DRYRUN] Would disable package user=0: $p"; return; }
  pkg_exists "$p" || { logi "Skip unavailable package: $p"; return; }
  is_protected_pkg "$p" && { logi "Skip protected/whitelisted package: $p"; return; }
  state="$(pkg_state "$p")"
  [ "$state" = "disabled" ] && { logi "Package already disabled user=0: $p"; return; }
  if pm disable-user --user 0 "$p" >/dev/null 2>&1; then
    record_applied package "$p"
    logi "Disabled OTA package user=0: $p"
  else
    logi "WARNING: Could not disable OTA package: $p"
  fi
}

google_pixel_components(){
  printf '%s\n' \
    'com.google.android.gms/.update.SystemUpdateService' \
    'com.google.android.gms/.update.SystemUpdateService$ActiveReceiver' \
    'com.google.android.gms/.update.SystemUpdateActivity' \
    'com.google.android.gms/.update.SystemUpdateGcmTaskService' \
    'com.google.android.gms/.update.SystemUpdatePersistentListenerService' \
    'com.google.android.gms/.update.SystemUpdateService$Receiver' \
    'com.google.android.gms/.update.SystemUpdateService$SecretCodeHandler' \
    'com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver' \
    'com.google.android.gms/.update.phone.PopupDialog' \
    'com.google.android.gms/.update.OtaSuggestionActivity' \
    'com.google.android.gsf/.update.SystemUpdateActivity' \
    'com.google.android.gsf/.update.SystemUpdatePanoActivity' \
    'com.google.android.gsf/.update.SystemUpdateService' \
    'com.google.android.gsf/.update.SystemUpdateService$Receiver' \
    'com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver'
}

resolve_system_update_activity(){
  cmd package resolve-activity --brief --user 0 -a android.settings.SYSTEM_UPDATE_SETTINGS 2>/dev/null | grep '/' | head -n 1
}

# The action resolver makes this work across Pixel releases without guessing a
# package.  A generic Settings dashboard or any non-SystemUpdate component is
# never disabled: losing the update button is acceptable, losing a whole
# Settings section is not.
is_safe_system_update_activity(){
  case "$1" in
    com.google.android.gms/.update.SystemUpdate*|\
    com.google.android.systemupdate/*SystemUpdate*|\
    com.android.settings/.Settings\$SystemUpdate*)
      return 0
      ;;
  esac
  return 1
}

block_resolved_system_update_activity(){
  quiet="${1:-false}"
  activity="$(resolve_system_update_activity)"
  [ -n "$activity" ] || { [ "$quiet" = true ] || logi "No handler resolved for android.settings.SYSTEM_UPDATE_SETTINGS"; return; }
  if is_safe_system_update_activity "$activity"; then
    [ "$quiet" = true ] || logi "Resolved system-update activity: $activity"
    disable_component_safely "$activity" "$quiet"
  else
    [ "$quiet" = true ] || logi "WARNING: Resolved update activity is not in the narrow allowlist; skipped: $activity"
  fi
}

block_google_pixel(){
  quiet="${1:-false}"
  [ "$quiet" = true ] || logi "Applying safe Google Pixel OTA rule set"
  for c in $(google_pixel_components); do
    disable_component_safely "$c" "$quiet"
  done
  block_resolved_system_update_activity "$quiet"
  # This package is the explicit Pixel system-update UI/provider.  It is
  # changed only when installed and enabled for user 0, and is fully restorable.
  disable_package_safely "com.google.android.systemupdate"
}

vendor_targets(){
  case "$VENDOR" in
    samsung) echo "com.wssyncmldm com.sec.android.soagent com.sec.android.fotaclient com.samsung.sdm com.samsung.sdm.sdmviewer com.samsung.android.lool" ;;
    xiaomi) echo "com.android.updater com.miui.rom" ;;
    oppo) echo "com.coloros.sau com.oplus.ota com.oplus.sau com.oplus.romupdate" ;;
    vivo) echo "com.bbk.updater com.vivo.upslide" ;;
    huawei) echo "com.huawei.android.hwouc com.huawei.android.hwouc.overlay" ;;
    motorola) echo "com.motorola.ccc.ota com.motorola.android.fota" ;;
    sony) echo "com.sonyericsson.updatecenter com.sonymobile.updatecenter" ;;
    asus) echo "com.asus.dm com.asus.systemupdate com.asus.updatecenter" ;;
    nothing) echo "com.nothing.ota com.nothing.systemupdate" ;;
    nokia) echo "com.evenwell.ota com.evenwell.otaservice com.hmdglobal.app.update" ;;
    lg) echo "com.lge.lgdmsclient com.lge.updatecenter" ;;
    *) echo "com.android.updater" ;;
  esac
}

user_blacklist_targets(){
  [ -f "$USER_BLACKLIST" ] || return
  grep -v '^[[:space:]]*#' "$USER_BLACKLIST" | sed '/^[[:space:]]*$/d'
}

block_vendor_packages(){
  for p in $(vendor_targets; user_blacklist_targets); do
    disable_package_safely "$p"
  done
}

scan_ota_packages(){
  echo "Installed packages matching OTA/update keywords:"
  pm list packages 2>/dev/null | cut -d: -f2 | grep -iE "ota|fota|update|updater|systemupdate|fotaclient|soagent|wssync|hwouc|sau|romupdate|dmclient|device.*management" | sort
}

scan_smart(){
  pm list packages 2>/dev/null | cut -d: -f2 | grep -iE "ota|fota|systemupdate|fotaclient|soagent|wssync|hwouc|romupdate|updater|updatecenter|dmclient|device.*management|ccc.ota|sau" | sort > "$SMART_SCAN_LIST"
  logi "Smart scan saved: $SMART_SCAN_LIST"
  cat "$SMART_SCAN_LIST"
}

block_smart_targets(){
  [ -f "$SMART_SCAN_LIST" ] || { logi "Smart block skipped: run scan-smart first"; return; }
  logi "WARNING: Applying user-requested Smart Block targets"
  while IFS= read -r p; do
    [ -n "$p" ] && disable_package_safely "$p"
  done < "$SMART_SCAN_LIST"
}

health_check(){
  clear_component_dump_cache
  detect_device
  if [ "$VENDOR" = "google" ]; then
    for c in $(google_pixel_components); do
      if component_exists "$c"; then
        state="$(component_state "$c")"
        echo "Component $c: $state"
        logi "Health component $c: $state"
      else
        echo "Component $c: unavailable"
        logi "Health component unavailable: $c"
      fi
    done
    p="com.google.android.systemupdate"
    state="$(pkg_state "$p")"
    echo "Package $p: $state"
    logi "Health package $p: $state"
    activity="$(resolve_system_update_activity)"
    if [ -z "$activity" ]; then
      echo "Resolved system-update activity: unavailable"
      logi "Health resolved system-update activity: unavailable"
    elif is_safe_system_update_activity "$activity"; then
      state="$(component_state "$activity")"
      echo "Resolved system-update activity $activity: $state"
      logi "Health resolved system-update activity $activity: $state"
    else
      echo "Resolved system-update activity $activity: skipped (outside allowlist)"
      logi "Health resolved system-update activity outside allowlist: $activity"
    fi
  else
    for p in $(vendor_targets); do
      state="$(pkg_state "$p")"
      echo "Package $p: $state"
      logi "Health package $p: $state"
    done
  fi
  clear_component_dump_cache
}

write_json_report(){
  detect_device
  active=true
  [ -f "$DISABLE_FILE" ] && active=false
  dryrun=false
  [ -f "$DRYRUN_FILE" ] && dryrun=true
  smart_block=false
  [ -f "$SMART_BLOCK_FILE" ] && smart_block=true
  applied_count=0
  [ -f "$APPLIED_LIST" ] && applied_count="$(wc -l < "$APPLIED_LIST" | tr -d ' ')"
  smart_count=0
  [ -f "$SMART_SCAN_LIST" ] && smart_count="$(wc -l < "$SMART_SCAN_LIST" | tr -d ' ')"
  version="$(module_value version)"
  version_code="$(module_value versionCode)"
  cat > "$REPORT_JSON" <<EOF
{"module":"Block OTA Update","version":"$version","versionCode":$version_code,"active":$active,"dryrun":$dryrun,"smart_block":$smart_block,"vendor":"$VENDOR","brand":"$BRAND","manufacturer":"$MANUFACTURER","model":"$MODEL","device":"$DEVICE","android_release":"$RELEASE","sdk":"$SDK","ab_ota":"$AB_OTA","slot":"$SLOT","applied_record_count":$applied_count,"smart_scan_count":$smart_count,"log":"$LOG"}
EOF
}

write_html_report(){
  write_json_report
  cat > "$REPORT_HTML" <<EOF
<!doctype html><html><head><meta charset="utf-8"><title>Block OTA Update</title><style>body{font-family:Arial;background:#111;color:#eee;padding:20px}.card{background:#1d1d1d;border-radius:12px;padding:16px;margin:12px 0}.ok{color:#6ee77a}.warn{color:#ffd166}pre{white-space:pre-wrap;background:#0b0b0b;padding:12px;border-radius:8px}</style></head><body><h1>Block OTA Update</h1><div class="card"><b>Vendor:</b> $VENDOR<br><b>Brand:</b> $BRAND<br><b>Manufacturer:</b> $MANUFACTURER<br><b>Model:</b> $MODEL<br><b>Android:</b> $RELEASE / SDK $SDK<br><b>A/B OTA:</b> $AB_OTA</div><div class="card"><b>Status:</b> $( [ -f "$DISABLE_FILE" ] && echo '<span class="warn">PAUSED</span>' || echo '<span class="ok">ACTIVE</span>' )<br><b>Dry-run:</b> $( [ -f "$DRYRUN_FILE" ] && echo yes || echo no )<br><b>Smart block:</b> $( [ -f "$SMART_BLOCK_FILE" ] && echo armed || echo off )</div><div class="card"><h2>Module-owned changes</h2><pre>$( [ -f "$APPLIED_LIST" ] && cat "$APPLIED_LIST" || echo none )</pre></div><div class="card"><h2>Smart scan targets</h2><pre>$( [ -f "$SMART_SCAN_LIST" ] && cat "$SMART_SCAN_LIST" || echo none )</pre></div><div class="card"><h2>Log tail</h2><pre>$( tail -n 80 "$LOG" 2>/dev/null )</pre></div></body></html>
EOF
  echo "$REPORT_HTML"
}

github_help(){
  cat <<EOF
GitHub release setup:
1) From v7.1 onward, set the same vM.m version in module.prop and update.json.
   Set versionCode to M * 100 + m (v7.1 = 701; v7.9 = 709; v8.0 = 800).
2) Commit and push main.
3) Create and push tag vM.m. GitHub Actions validates metadata, builds the ZIP, and creates the release.
EOF
}

status_report(){
  detect_device
  write_json_report
  echo "Block OTA Update"
  echo "Vendor: $VENDOR"
  echo "Brand: $BRAND"
  echo "Manufacturer: $MANUFACTURER"
  echo "Model: $MODEL"
  echo "Android: $RELEASE / SDK $SDK"
  echo "A/B OTA: $AB_OTA Slot: $SLOT"
  [ -f "$DISABLE_FILE" ] && echo "Status: PAUSED" || echo "Status: ACTIVE"
  [ -f "$SMART_BLOCK_FILE" ] && echo "Smart block: ARMED (manual only)" || echo "Smart block: OFF"
  [ -f "$DRYRUN_FILE" ] && echo "Dry-run: ON" || echo "Dry-run: OFF"
  echo "JSON report: $REPORT_JSON"
  echo "HTML report: $REPORT_HTML"
  tail -n 30 "$LOG" 2>/dev/null
}

block_all(){
  quiet="${1:-false}"
  [ -f "$DISABLE_FILE" ] && {
    [ "$quiet" = true ] || { logi "Paused: $DISABLE_FILE exists"; write_json_report; }
    return 0
  }
  detect_device
  [ "$quiet" = true ] || logi "Applying safe OTA rules for vendor=$VENDOR model=$MODEL android=$RELEASE sdk=$SDK"
  if [ "$VENDOR" = "google" ]; then
    clear_component_dump_cache
    block_google_pixel "$quiet"
  else
    block_vendor_packages
  fi
  if [ "$quiet" != true ]; then
    clear_component_dump_cache
    health_check >/dev/null
  fi
  [ "$quiet" = true ] || write_json_report
  [ "$quiet" = true ] || logi "Safe OTA block cycle complete"
}

apply_boot_rules(){
  quiet="${1:-false}"
  detect_device
  if [ "$VENDOR" = "google" ]; then
    block_all "$quiet"
  else
    logi "Boot auto-block skipped for vendor=$VENDOR; use blockota block explicitly"
    write_json_report
  fi
}

restore_all(){
  pending="$STATE_DIR/applied_v4.pending.$$"
  [ -f "$APPLIED_LIST" ] || { logi "No module-owned changes to restore"; write_json_report; return 0; }
  : > "$pending" || { logi "WARNING: Cannot create restore state file"; return 1; }
  while IFS='|' read -r kind target; do
    [ -n "$kind" ] || continue
    restored=false
    case "$kind" in
      component)
        if ! component_exists "$target"; then
          restored=true
          logi "Component no longer present; dropped restore record: $target"
        elif pm enable --user 0 "$target" >/dev/null 2>&1; then
          restored=true
          logi "Restored component user=0: $target"
        fi
        ;;
      package)
        if ! pkg_exists "$target"; then
          restored=true
          logi "Package no longer present; dropped restore record: $target"
        elif pm enable --user 0 "$target" >/dev/null 2>&1; then
          restored=true
          logi "Restored package user=0: $target"
        fi
        ;;
      *)
        restored=true
        logi "Dropped invalid restore record: $kind|$target"
        ;;
    esac
    if [ "$restored" = true ]; then
      :
    else
      echo "$kind|$target" >> "$pending"
      logi "WARNING: Restore failed; keeping record: $kind|$target"
    fi
  done < "$APPLIED_LIST"
  if [ -s "$pending" ]; then
    mv "$pending" "$APPLIED_LIST"
  else
    rm -f "$pending" "$APPLIED_LIST"
  fi
  [ -f "$LEGACY_DISABLED_LIST" ] && logi "Legacy v3 disable list retained untouched for safety: $LEGACY_DISABLED_LIST"
  write_json_report
  logi "Restore cycle complete"
}
