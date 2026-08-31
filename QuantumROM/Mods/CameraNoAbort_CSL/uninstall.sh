#!/system/bin/sh
# TRACE/52 v1.2 rollback: systemless removal only; vendor real nunca e escrito.
MODDIR=${0%/*}
LOG="$MODDIR/patch.log"
echo "[a52s-csl] $(date '+%F %T') systemless uninstall requested; no vendor write and no wipe" >> "$LOG"
# Magisk/KernelSU remove the overlay with the module itself. Reboot completes the rollback.
exit 0
