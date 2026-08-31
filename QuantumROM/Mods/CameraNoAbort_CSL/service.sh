#!/system/bin/sh
# TRACE/52: neutraliza somente o raise(6) confirmado no backtrace.
# Nao corrige o NACK I2C/power-sequence; recusa binarios desconhecidos.
MODDIR=${0%/*}
BIN=/vendor/lib64/hw/camera.qcom.so
OFFSET=0xc88b4c
ORIG_SHA=8ec1d39fa64be468401ffad92dbf9588edd32ab3f8574202bcfd73e79be97695
PATCH_SHA=0de3cc79b89e4263375ba2a82e862d02e0a20135cd3c340c2c5628cb00b7f360
LOG="$MODDIR/patch.log"
log() { echo "[a52s-csl] $(date '+%F %T') $*" >> "$LOG"; }
patch_vendor() {
  [ -f "$BIN" ] || { log "camera.qcom.so nao encontrado"; return 1; }
  sha=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')
  case "$sha" in
    "$PATCH_SHA") log "ja aplicado; nenhuma escrita"; return 0 ;;
    "$ORIG_SHA") ;;
    *) log "hash desconhecido=$sha; recusando alteracao"; return 2 ;;
  esac
  mount -o remount,rw /vendor 2>/dev/null || { log "remount rw falhou"; return 3; }
  cp -f "$BIN" "$MODDIR/camera.qcom.so.orig" 2>/dev/null || { log "backup falhou"; mount -o remount,ro /vendor 2>/dev/null; return 4; }
  printf '\037\040\003\325' | dd of="$BIN" bs=1 seek=$((OFFSET)) conv=notrunc 2>/dev/null || { log "escrita falhou"; mount -o remount,ro /vendor 2>/dev/null; return 5; }
  newsha=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')
  if [ "$newsha" = "$PATCH_SHA" ]; then log "patch OK; original=$ORIG_SHA patched=$PATCH_SHA"; else log "verificacao falhou hash=$newsha; restaurando"; cp -f "$MODDIR/camera.qcom.so.orig" "$BIN" 2>/dev/null; mount -o remount,ro /vendor 2>/dev/null; return 6; fi
  mount -o remount,ro /vendor 2>/dev/null
  setprop ctl.restart vendor.camera-provider-2-0 2>/dev/null
  setprop ctl.restart vendor.camera-provider 2>/dev/null
  log "provider restart solicitado; userdata e wipe nao foram tocados"
}
sleep 15
patch_vendor
