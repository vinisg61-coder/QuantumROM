#!/system/bin/sh
# a52s-camera-no-abort-csl — reaplica o NOP no boot (todo boot, se o vendor voltar ao original
# Seguro: so mexe se o hash atual for o ORIGINAL (ou ja o PATCHED

MODULE_DIR=/${0%/*}
BIN=/vendor/lib64/hw/camera.qcom.so
OFFSET=$((0xc88b4c))
ORIG_SHA=8ec1d39fa64be468401ffad92dbf9588edd32ab3f8574202bcfd73e79be97695
PATCH_SHA=0de3cc79b89e4263375ba2a82e862d02e0a20135cd3c340c2c5628cb00b7f360
LOG=$MODULE_DIR/patch.log

log() {
    echo "[a52s-camera] $(date) $*" >> $LOG
}

apply_patch() {
    mount -o remount,rw /vendor 2>/dev/null
    sha=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')
    case "$sha" in
        "$PATCH_SHA")
            log "ja patched ($sha)"
            ;;
        "$ORIG_SHA")
            cp -f "$BIN" "$BIN.bak" 2>/dev/null
            chmod 644 "$BIN" 2>/dev/null
            if printf '\x1f\x20\x03\xd5' | dd of="$BIN" bs=1 seek=$OFFSET conv=notrunc 2>/dev/null; then
                log "patch reaplicado no boot"
            else
                log "falha ao reaplicar patch"
            fi
            ;;
        *)
            log "hash desconhecido ($sha) — nao mexe"
            ;;
    esac
    mount -o remount,ro /vendor 2>/dev/null
}

# da um tempo pro vendor montar no boot
sleep 15
if [ -f "$BIN" ]; then
    apply_patch
fi