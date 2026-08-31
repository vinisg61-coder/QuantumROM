#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/activation.log"
EXPECTED=""
TARGET="/vendor/lib64/hw/camera.qcom.so"
{
  echo "[a52s-vendor16] $(date -Iseconds) boot check"
  echo "[a52s-vendor16] module_path=$MODDIR"
  if [ -f "$MODDIR/vendor/lib64/hw/camera.qcom.so" ]; then
    EXPECTED=$(sha256sum "$MODDIR/vendor/lib64/hw/camera.qcom.so" 2>/dev/null | awk '{print $1}')
    echo "[a52s-vendor16] module_sha=$EXPECTED"
  else
    echo "[a52s-vendor16] ERROR module camera.qcom.so missing"
  fi
  if [ -f "$TARGET" ]; then
    ACTUAL=$(sha256sum "$TARGET" 2>/dev/null | awk '{print $1}')
    echo "[a52s-vendor16] target_sha=$ACTUAL"
    if [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ]; then
      echo "[a52s-vendor16] overlay_visible=yes"
    else
      echo "[a52s-vendor16] overlay_visible=no"
    fi
  else
    echo "[a52s-vendor16] target_missing=$TARGET"
  fi
  grep -E ' /vendor ' /proc/mounts 2>/dev/null | head -n 3
} >> "$LOG" 2>&1
