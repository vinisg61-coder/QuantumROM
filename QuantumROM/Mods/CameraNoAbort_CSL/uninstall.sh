#!/system/bin/sh
# TRACE/52 rollback: restore only the backup created by this module.
MODDIR=${0%/*}
BIN=/vendor/lib64/hw/camera.qcom.so
BACKUP="$MODDIR/camera.qcom.so.orig"
PATCH_SHA=0de3cc79b89e4263375ba2a82e862d02e0a20135cd3c340c2c5628cb00b7f360
LOG="$MODDIR/patch.log"
echo "[a52s-csl] $(date '+%F %T') uninstall requested" >> "$LOG"
[ -f "$BACKUP" ] || exit 0
current=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')
[ "$current" = "$PATCH_SHA" ] || { echo "[a52s-csl] not restoring unknown/current hash=$current" >> "$LOG"; exit 0; }
mount -o remount,rw /vendor 2>/dev/null || exit 1
cp -f "$BACKUP" "$BIN" 2>/dev/null || { mount -o remount,ro /vendor 2>/dev/null; exit 1; }
mount -o remount,ro /vendor 2>/dev/null
setprop ctl.restart vendor.camera-provider-2-0 2>/dev/null
setprop ctl.restart vendor.camera-provider 2>/dev/null
echo "[a52s-csl] original restored; no wipe performed" >> "$LOG"
exit 0
