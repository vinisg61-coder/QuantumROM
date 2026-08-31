#!/system/bin/sh
# TRACE/52 v1.2 — systemless overlay; nunca remonta nem escreve o /vendor real.
# O binario e copiado do aparelho durante a instalacao e patchado dentro de MODPATH.

MODPATH=${MODPATH:-/${0%/*}}
SRC=/vendor/lib64/hw/camera.qcom.so
OFFSET=$((0xc88b4c))
ORIG_SHA=8ec1d39fa64be468401ffad92dbf9588edd32ab3f8574202bcfd73e79be97695
PATCH_SHA=0de3cc79b89e4263375ba2a82e862d02e0a20135cd3c340c2c5628cb00b7f360

ui_print() { echo "- $*"; }
fail() { ui_print "ABORTADO: $*"; exit 1; }

[ -f "$SRC" ] || fail "camera.qcom.so nao encontrado em $SRC"
# KernelSU monta o proprio module root; Magisk usa system/vendor para o vendor.
# A v1.2 usou system/vendor e ficou invisivel no /vendor deste aparelho KernelSU.
if [ -d /data/adb/ksu ] || su -v 2>/dev/null | grep -qi 'kernelsu'; then
  DST="$MODPATH/vendor/lib64/hw/camera.qcom.so"
  MODE=ksu-vendor-overlay
else
  DST="$MODPATH/system/vendor/lib64/hw/camera.qcom.so"
  MODE=magisk-system-vendor-overlay
fi
mkdir -p "${DST%/*}" || fail "nao foi possivel criar o overlay"
sha=$(sha256sum "$SRC" 2>/dev/null | awk '{print $1}')
[ "$sha" = "$ORIG_SHA" ] || fail "hash original inesperado: $sha"
cp -f "$SRC" "$DST" || fail "falha ao copiar camera.qcom.so para o overlay"
chmod 0644 "$DST" 2>/dev/null
printf '\037\040\003\325' | dd of="$DST" bs=1 seek=$((OFFSET)) conv=notrunc 2>/dev/null || fail "falha ao escrever NOP no overlay"
patched=$(sha256sum "$DST" 2>/dev/null | awk '{print $1}')
[ "$patched" = "$PATCH_SHA" ] || fail "hash pos-patch inesperado: $patched"
printf 'original_sha=%s\npatched_sha=%s\noffset=0xc88b4c\nmode=%s\npath=%s\n' "$ORIG_SHA" "$PATCH_SHA" "$MODE" "$DST" > "$MODPATH/patch_state.txt"
ui_print "OK: overlay $MODE criado"
ui_print "OK: nenhum remount do /vendor e nenhum wipe executado"
