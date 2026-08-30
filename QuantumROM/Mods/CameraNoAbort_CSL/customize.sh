#!/system/bin/sh
# a52s-camera-no-abort-csl — NOPa o raise(6) no CSLAcquireDeviceHW do camera.qcom.so
# BuildId 9b26d985843faf46e36d82967f1c1526 — offset 0xc88b4c: 49 a1 01 94 (bl raise( -> 1f 20 03 d5 (NOP
# Evita que o provider de camera abort(e (SIGABRT) quando o acquire do sensor principal falha

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
    log "Vendor mount: $(mount | grep ' /vendor ' | awk '{print $4}')"
    mount -o remount,rw /vendor 2>/dev/null
    log "remount rw rc=$?"
    if ! sha256sum "$BIN" 2>/dev/null | grep -q "$ORIG_SHA"; then
        log "sha256 NAO bate com original — abortando (patch nao aplicado)"
        sha=$(sha256sum "$BIN" 2>/dev/null | awk '{print $1}')
        log "hash atual: $sha"
        mount -o remount,ro /vendor 2>/dev/null
        return 1
    fi
    cp -f "$BIN" "$BIN.bak" 2>/dev/null
    chmod 644 "$BIN" 2>/dev/null
    if ! printf '\x1f\x20\x03\xd5' | dd of="$BIN" bs=1 seek=$OFFSET conv=notrunc 2>/dev/null; then
        log "falha ao escrever patch"
        mount -o remount,ro /vendor 2>/dev/null
        return 1
    fi
    # confere
    if sha256sum "$BIN" 2>/dev/null | grep -q "$PATCH_SHA"; then
        log "PATCH OK — provider de camera nao vai mais abortar no CSL"
    else
        log "verificacao falhou — revertendo"
        cp -f "$BIN.bak" "$BIN" 2>/dev/null
    fi
    mount -o remount,ro /vendor 2>/dev/null
    return 0
}

restart_provider() {
    # S + restarta o provider de camera para aplicar sem reboot
    setprop ctl.stop vendor.camera-provider-2-0 2>/dev/null
    setprop ctl.restart vendor.camera-provider-2-0 2>/dev/null
    setprop ctl.restart vendor.camera-provider 2>/dev/null
    sleep 22
    # kill forcas se o setprop nao pegar
    for p in $(pgrep -f "vendor.samsung.hardware.camera.provider"); do
        kill -9 $p 2>/dev/null
    done
}

if [ -f "$BIN" ]; then
    apply_patch
    restart_provider
fi