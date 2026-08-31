#!/system/bin/sh
# TRACE/52 v1.2 — o patch vive no overlay Magisk/KernelSU; nao escreve /vendor.
MODDIR=${0%/*}
BIN=/vendor/lib64/hw/camera.qcom.so
PATCH_SHA=0de3cc79b89e4263375ba2a82e862d02e0a20135cd3c340c2c5628cb00b7f360
LOG="$MODDIR/patch.log"
log() { echo "[a52s-csl] $(date '+%F %T') $*" >> "$LOG"; }
sleep 15
if [ -f "$BIN" ]; then
  sha=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')
  if [ "$sha" = "$PATCH_SHA" ]; then
    log "systemless overlay ativo; hash=$sha; nenhum remount/escrita realizado"
  else
    log "overlay nao visivel ou hash inesperado=$sha; nenhuma alteracao realizada"
  fi
else
  log "camera.qcom.so nao encontrado; nenhuma alteracao realizada"
fi
