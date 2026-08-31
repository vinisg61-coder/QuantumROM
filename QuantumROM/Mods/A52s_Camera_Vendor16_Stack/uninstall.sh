#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/activation.log"
echo "[a52s-vendor16] $(date -Iseconds) uninstall requested; systemless files will be removed by KernelSU; no vendor write or wipe" >> "$LOG" 2>&1
