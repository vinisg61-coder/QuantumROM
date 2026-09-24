#!/bin/bash
# =============================================================================
#  QuantumROM — unica_camera.sh
#  Camera patch adapted from UN1CA ROM's patches/camera/customize.sh
#
#  Required vars (set by sixteen.sh / QuantumRom.sh):
#    FIRM_DIR, TARGET_DEVICE, STOCK_DEVICE, DEVICES_DIR
#    WORK_DIR, APKTOOL
#
#  Device config (floating_feature.xml) lives at:
#    $DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml  ← target (S20)
#
#  Stock firmware of target device lives at:
#    $FIRM_DIR/$TARGET_DEVICE/  ← S23 FE (being ported)
# =============================================================================
source scripts/smali_patch.sh
# ── Helper: read a flag from floating_feature.xml ─────────────────────────────
# Usage:
#   GET_FLOATING_FEATURE_CONFIG "FLAG"            → reads from SOURCE (S23 FE)
#   GET_FLOATING_FEATURE_CONFIG "/path/to/ff.xml" "FLAG" → reads from given xml
GET_FLOATING_FEATURE_CONFIG() {
    local XML_PATH FLAG

    if [ "$#" -eq 2 ]; then
        XML_PATH="$1"
        FLAG="$2"
    else
        # Source = firmware being ported (S23 FE)
        XML_PATH="$FIRM_DIR/$TARGET_DEVICE/system/system/etc/floating_feature.xml"
        FLAG="$1"
    fi

    grep -oP "(?<=<$FLAG>)[^<]+" "$XML_PATH" 2>/dev/null || true
}

# Shorthand: get flag from TARGET device config (S20)
GET_TARGET_FLOATING_FEATURE() {
    GET_FLOATING_FEATURE_CONFIG \
        "$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml" "$1"
}

# ── Main camera patch function ────────────────────────────────────────────────
PATCH_SAMSUNG_CAMERA() {
    echo " "
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local PORT_DIR="$1"   # S23 FE firmware dir
    local STOCK_DIR="$DEVICES_DIR/$STOCK_DEVICE/Stock"   # S20 stock files
    local PORT_CAM="$PORT_DIR/system/system/cameradata"
    local STOCK_CAM="$STOCK_DIR/system/system/cameradata"

    # ── CONFIGURABLE PATHS / FLAGS — ajuste se algo estiver errado ─────────────
    # Pasta opcional com overrides manuais por device para os 3 XMLs de câmera
    # (equivalente ao $SRC_DIR/target/$TARGET_CODENAME/camera/ do ArtisanROM).
    # Se você não mantém overrides manuais, pode deixar como está: os checks
    # simplesmente não vão encontrar nada e cairão no fallback (cópia do stock).
    local DEVICE_CAM_OVERRIDES="$DEVICES_DIR/$STOCK_DEVICE/camera"

    # build.prop usados para comparar SDK version entre doador e stock alvo
    local PORT_BUILD_PROP="$PORT_DIR/system/system/build.prop"
    local STOCK_BUILD_PROP="$DEVICES_DIR/$STOCK_DEVICE/build.prop"

    # Pasta de overlays do product, usada para pular o patch de cutout protection
    # se já existir uma RRO de SystemUI aplicada
    local SYSTEMUI_OVERLAY_DIR="$PORT_DIR/product/overlay"

    # Ativa o hex patch de object capture (libobjectcapture_jni.arcsoft.so).
    # Isso só é relevante em builds "essi" (single system image) para devices
    # específicos da Samsung (r0/g0/b0/a56*). Deixe "false" a menos que você
    # tenha certeza que seu STOCK_DEVICE/TARGET_DEVICE se encaixam nesse caso -
    # ver TODO na seção correspondente antes de ativar.
    local ENABLE_OBJECT_CAPTURE_FIX=true

    # Ativa o patch de cutout protection na SystemUI. Depende de você definir
    # como descobrir SOURCE/TARGET_CAMERA_SUPPORT_CUTOUT_PROTECTION no seu
    # sistema (não vem do floating_feature.xml no script original) - ver TODO.
    local ENABLE_CUTOUT_PROTECTION_FIX=false

    echo "- Patching UN1CA Camera..."

    # ── 1. Replace portrait_data from target (S20) ────────────────────────────
    if [ -d "$STOCK_CAM/portrait_data" ]; then
        echo "  - Replacing portrait_data"
        rm -rf "$PORT_CAM/portrait_data"
        cp -a "$STOCK_CAM/portrait_data" "$PORT_CAM/portrait_data"
    fi

    # ── 2. singletake/service-feature.xml ────────────────────────────────────
    if [ -f "$DEVICE_CAM_OVERRIDES/singletake/service-feature.xml" ]; then
        echo "  - Adding device override: singletake/service-feature.xml"
        cp -a "$DEVICE_CAM_OVERRIDES/singletake/service-feature.xml" \
              "$PORT_CAM/singletake/service-feature.xml"
    elif [ -f "$STOCK_CAM/singletake/service-feature.xml" ]; then
        echo "  - Replacing singletake/service-feature.xml"
        cp -f "$STOCK_CAM/singletake/service-feature.xml" \
              "$PORT_CAM/singletake/service-feature.xml"
    fi

    # ── 3. aremoji-feature.xml ────────────────────────────────────────────────
    if [ -f "$DEVICE_CAM_OVERRIDES/aremoji-feature.xml" ]; then
        echo "  - Adding device override: aremoji-feature.xml"
        cp -a "$DEVICE_CAM_OVERRIDES/aremoji-feature.xml" \
              "$PORT_CAM/aremoji-feature.xml"
    elif [ -f "$STOCK_CAM/aremoji-feature.xml" ]; then
        echo "  - Replacing aremoji-feature.xml"
        cp -f "$STOCK_CAM/aremoji-feature.xml" \
              "$PORT_CAM/aremoji-feature.xml"
    fi

    # ── 4. camera-feature.xml ────────────────────────────────────────────────
    # No original, isso só é copiado do stock se SOURCE_PLATFORM_SDK_VERSION ==
    # TARGET_PLATFORM_SDK_VERSION (senão aborta, para não misturar formatos de
    # XML incompatíveis entre versões de Android). Reproduzido abaixo lendo o
    # SDK de $PORT_BUILD_PROP (doador) e $STOCK_BUILD_PROP (device alvo).
    local PORT_SDK STOCK_SDK
    PORT_SDK="$(grep -m1 '^ro.build.version.sdk=' "$PORT_BUILD_PROP" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')"
    STOCK_SDK="$(grep -m1 '^ro.build.version.sdk=' "$STOCK_BUILD_PROP" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')"

    if [ -f "$DEVICE_CAM_OVERRIDES/camera-feature.xml" ]; then
        echo "  - Adding device override: camera-feature.xml"
        cp -a "$DEVICE_CAM_OVERRIDES/camera-feature.xml" "$PORT_CAM/camera-feature.xml"
    elif [ -f "$STOCK_CAM/camera-feature.xml" ]; then
        if [ "$PORT_SDK" ] && [ "$PORT_SDK" == "$STOCK_SDK" ]; then
            echo "  - Replacing camera-feature.xml"
            cp -f "$STOCK_CAM/camera-feature.xml" "$PORT_CAM/camera-feature.xml"
        else
            echo "  - WARNING: SDK version mismatch (port=$PORT_SDK stock=$STOCK_SDK)," \
                 "keeping donor camera-feature.xml unchanged"
        fi
    fi

    # Remove Smart View limitations
    if grep -q "DURING_SMARTVIEW" "$PORT_CAM/camera-feature.xml" 2>/dev/null; then
        echo "  - Removing Smart View limitation flags"
        sed -i "/DURING_SMARTVIEW/d" "$PORT_CAM/camera-feature.xml"
    fi

    # Remove native blur disable flag if device supports 3D surface transitions
    local SUPPORT_3D
    SUPPORT_3D="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_3D_SURFACE_TRANSITION_FLAG")"
    if [ "$SUPPORT_3D" ] && grep -q "SUPPORT_LIVE_BLUR" "$PORT_CAM/camera-feature.xml" 2>/dev/null; then
        echo "  - Removing native blur disable flag"
        sed -i "/SUPPORT_LIVE_BLUR/d" "$PORT_CAM/camera-feature.xml"
    fi

    # ── 4b. SamsungCamera "hal3_mass-phone-release" app flavor ───────────────
    # TODO: no ArtisanROM original, SOURCE/TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR
    # são booleanos vindos de fora deste arquivo (definidos em outro lugar do
    # framework, não no floating_feature.xml). Eu não sei como você detecta
    # isso no seu sistema, então deixei como placeholder desativado — ajuste
    # a condição abaixo (ou apague o bloco) conforme sua lógica real.
    local SOURCE_CAMERA_SUPPORT_MASS_APP_FLAVOR=false
    local TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR=false
    if ! $SOURCE_CAMERA_SUPPORT_MASS_APP_FLAVOR && $TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR; then
        # Busca o apk no STOCK_DIR (S20), no mesmo caminho relativo do PORT_DIR
        if [ -f "$STOCK_DIR/system/system/priv-app/SamsungCamera/SamsungCamera.apk" ]; then
            echo "  - Adding mass-phone-release SamsungCamera.apk (from stock)"
            mkdir -p "$PORT_DIR/system/system/priv-app/SamsungCamera"
            cp -f "$STOCK_DIR/system/system/priv-app/SamsungCamera/SamsungCamera.apk" \
                  "$PORT_DIR/system/system/priv-app/SamsungCamera/SamsungCamera.apk"
            [ -f "$STOCK_DIR/system/system/priv-app/SamsungCamera/SamsungCamera.apk.prof" ] && \
                cp -f "$STOCK_DIR/system/system/priv-app/SamsungCamera/SamsungCamera.apk.prof" \
                      "$PORT_DIR/system/system/priv-app/SamsungCamera/SamsungCamera.apk.prof"
        else
            echo "  - WARNING: TARGET needs mass-phone-release SamsungCamera.apk" \
                 "but it wasn't found in \$STOCK_DIR/system/system/priv-app/SamsungCamera"
        fi
    fi

    # ── 4c. Single Take "stp1-release" app flavor ─────────────────────────────
    if grep -q "SUPPORT_SINGLE_TAKE_HIGHLIGHT_VIDEOS.*true" "$STOCK_CAM/camera-feature.xml" 2>/dev/null && \
       ! grep -q "SUPPORT_SINGLE_TAKE_HIGHLIGHT_VIDEOS.*true" "$PORT_CAM/camera-feature.xml" 2>/dev/null; then
        # Busca o apk no STOCK_DIR (S20), no mesmo caminho relativo do PORT_DIR
        if [ -f "$STOCK_DIR/system/system/priv-app/SingleTakeService/SingleTakeService.apk" ]; then
            echo "  - Adding SingleTakeService.apk (stp1-release flavor, from stock)"
            mkdir -p "$PORT_DIR/system/system/priv-app/SingleTakeService"
            cp -f "$STOCK_DIR/system/system/priv-app/SingleTakeService/SingleTakeService.apk" \
                  "$PORT_DIR/system/system/priv-app/SingleTakeService/SingleTakeService.apk"
        else
            echo "  - WARNING: target supports SUPPORT_SINGLE_TAKE_HIGHLIGHT_VIDEOS" \
                 "but SingleTakeService.apk wasn't found in" \
                 "\$STOCK_DIR/system/system/priv-app/SingleTakeService"
        fi
    fi

    # ── 5. Snapchat CameraKit Plugin (FunModeSDK) ─────────────────────────────
    if [ -f "$PORT_DIR/system/system/app/FunModeSDK/FunModeSDK.apk" ]; then
        if ! grep -q "SHOOTING_MODE_FUN" "$PORT_CAM/camera-feature.xml" 2>/dev/null; then
            echo "  - Removing FunModeSDK (no SHOOTING_MODE_FUN in camera-feature.xml)"
            rm -rf "$PORT_DIR/system/system/app/FunModeSDK"
        fi
    else
        if grep -q "SHOOTING_MODE_FUN" "$PORT_CAM/camera-feature.xml" 2>/dev/null; then
            # Busca a pasta do apk no STOCK_DIR (S20), mesmo caminho relativo
            if [ -d "$STOCK_DIR/system/system/app/FunModeSDK" ]; then
                echo "  - Adding FunModeSDK (SHOOTING_MODE_FUN supported, apk missing, from stock)"
                cp -a "$STOCK_DIR/system/system/app/FunModeSDK" "$PORT_DIR/system/system/app/FunModeSDK"
            else
                echo "  - WARNING: SHOOTING_MODE_FUN supported but FunModeSDK.apk" \
                     "wasn't found in \$STOCK_DIR/system/system/app/FunModeSDK to add it back"
            fi
        fi
    fi

    # ── 6. SEC_PRODUCT_FEATURE_CAMERA_CONFIG_ACTION_CLASSIFIER ────────────────
    local SRC_ACTION_CLASSIFIER TGT_ACTION_CLASSIFIER
    SRC_ACTION_CLASSIFIER="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_CAMERA_CONFIG_ACTION_CLASSIFIER")"
    TGT_ACTION_CLASSIFIER="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_CAMERA_CONFIG_ACTION_CLASSIFIER")"

    if [ "$SRC_ACTION_CLASSIFIER" ]; then
        if [ "$TGT_ACTION_CLASSIFIER" ]; then
            # TODO: no original, isso copia vendor/etc/singletake/dynamic_viewing
            # do FIRMWARE DOADOR (SOURCE_FIRMWARE) por cima do WORK_DIR, porque lá
            # o WORK_DIR nasce como cópia do device alvo e recebe overlays do
            # doador. No SEU esquema não sei se $PORT_DIR já É uma cópia do
            # doador (nesse caso essa pasta já deve existir e nada precisa ser
            # feito) ou se a vendor partition do seu WORK_DIR vem de outro lugar.
            # Ajuste DYNAMIC_VIEWING_SRC abaixo para a pasta correta antes de
            # confiar neste bloco - por padrão ele só avisa, sem copiar nada.
            local DYNAMIC_VIEWING_SRC=""   # ex: "$FIRM_DIR/$TARGET_DEVICE"
            if [ "$DYNAMIC_VIEWING_SRC" ] && [ -d "$DYNAMIC_VIEWING_SRC/vendor/etc/singletake/dynamic_viewing" ]; then
                echo "  - Refreshing dynamic_viewing data (both support action classifier)"
                rm -rf "$PORT_DIR/vendor/etc/singletake/dynamic_viewing"
                mkdir -p "$PORT_DIR/vendor/etc/singletake"
                cp -a "$DYNAMIC_VIEWING_SRC/vendor/etc/singletake/dynamic_viewing" \
                      "$PORT_DIR/vendor/etc/singletake/dynamic_viewing"
            else
                echo "  - NOTE: both support action classifier — verify dynamic_viewing" \
                     "data is present/correct (see TODO, DYNAMIC_VIEWING_SRC not set)"
            fi
        else
            echo "  - Removing action classifier libs (not supported on target)"
            rm -f "$PORT_DIR/system/system/lib64/libVideoClassifier.camera.samsung.so"
            rm -f "$PORT_DIR/system/system/lib64/libtensorflowLite2_11_0_dynamic_camera.so"
        fi
    fi

    # ── 7. SEC_PRODUCT_FEATURE_CAMERA_CONFIG_GPPM_SOLUTIONS ──────────────────
    local SRC_GPPM TGT_GPPM
    SRC_GPPM="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_CAMERA_CONFIG_GPPM_SOLUTIONS")"
    TGT_GPPM="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_CAMERA_CONFIG_GPPM_SOLUTIONS")"

    if [[ "$SRC_GPPM" != "$TGT_GPPM" ]] && [ "$SRC_GPPM" ]; then
        if [ ! "$TGT_GPPM" ] && \
           [ ! -f "$STOCK_DIR/system/system/priv-app/GlobalPostProcMgr/GlobalPostProcMgr.apk" ]; then
            echo "  - Removing GlobalPostProcMgr"
            rm -f "$PORT_DIR/system/system/etc/default-permissions/default-permissions-com.samsung.android.globalpostprocmgr.xml"
            rm -f "$PORT_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.globalpostprocmgr.xml"
            rm -rf "$PORT_DIR/system/system/priv-app/GlobalPostProcMgr"
        fi
        if [[ "$SRC_GPPM" == *"startrail"* ]] && [[ "$TGT_GPPM" != *"startrail"* ]]; then
            echo "  - Removing startrail lib"
            rm -f "$PORT_DIR/system/system/lib64/libstartrail.camera.samsung.so"
        fi
        if [[ "$SRC_GPPM" == *"motionclipper"* ]] && [[ "$TGT_GPPM" != *"motionclipper"* ]]; then
            echo "  - Removing motionclipper lib"
            rm -f "$PORT_DIR/system/system/lib64/libdvs.camera.samsung.so"
        fi
    fi

    # ── 8. SEC_PRODUCT_FEATURE_CAMERA_SUPPORT_SDK_SERVICE ────────────────────
    local SRC_SDK_SVC TGT_SDK_SVC
    SRC_SDK_SVC="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_SDK_SERVICE")"
    TGT_SDK_SVC="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_SDK_SERVICE")"

    if [ "$SRC_SDK_SVC" ] && [ ! "$TGT_SDK_SVC" ]; then
        echo "  - Removing SCameraSDKService"
        rm -f "$PORT_DIR/system/system/etc/permissions/cameraservice.xml"
        rm -f "$PORT_DIR/system/system/framework/scamera_sep.jar"
        rm -rf "$PORT_DIR/system/system/priv-app/SCameraSDKService"
    fi

    # ── 9. SEC_PRODUCT_FEATURE_CAMERA_SUPPORT_CAMERAX_EXTENSION ──────────────
    local SRC_CAMERAX TGT_CAMERAX
    SRC_CAMERAX="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_CAMERAX_EXTENSION")"
    TGT_CAMERAX="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_CAMERAX_EXTENSION")"

    if [ "$SRC_CAMERAX" ] && [ ! "$TGT_CAMERAX" ]; then
        echo "  - Removing CameraX Extension"
        rm -f "$PORT_DIR/system/system/etc/permissions/sec_camerax_impl.xml"
        rm -f "$PORT_DIR/system/system/etc/permissions/sec_camerax_service.xml"
        rm -f "$PORT_DIR/system/system/framework/sec_camerax_impl.jar"
        rm -f "$PORT_DIR/system/system/lib/libsec_camerax_util_jni.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libsec_camerax_util_jni.camera.samsung.so"
        rm -rf "$PORT_DIR/system/system/priv-app/sec_camerax_service"
        sed -i "/^ro.camerax.extensions.enabled=/d" \
            "$PORT_DIR/system/system/build.prop" 2>/dev/null
    fi

    # ── 10. Camera vendor lib debloat based on SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO ──
    local SRC_VLIB TGT_VLIB
    SRC_VLIB="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO")"
    TGT_VLIB="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO")"

    # libRelighting (single bokeh)
    if ! grep -q '"system"' "$PORT_CAM/portrait_data/single_bokeh_feature.json" 2>/dev/null; then
        echo "  - Removing libRelighting_API"
        rm -f "$PORT_DIR/system/system/lib64/libRelighting_API.camera.samsung.so"
    fi

    # ── ARDOODLE_LIB: pasta system/etc/ardoodle ───────────────────────────────
    local SRC_ARDOODLE TGT_ARDOODLE
    SRC_ARDOODLE="$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SAIV_CONFIG_ARDOODLE_LIB")"
    TGT_ARDOODLE="$(GET_TARGET_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SAIV_CONFIG_ARDOODLE_LIB")"

    if [[ "$SRC_ARDOODLE" == *"IMG_PICKING"* ]] && [[ "$TGT_ARDOODLE" != *"IMG_PICKING"* ]]; then
        echo "  - Removing ardoodle (IMG_PICKING not supported on target)"
        rm -rf "$PORT_DIR/system/system/etc/ardoodle"
    fi

    # lib_pet_detection
    if ! grep -q "SUPPORT_PET_DETECTION.*true" "$PORT_CAM/singletake/service-feature.xml" 2>/dev/null \
            && [[ "$TGT_ARDOODLE" != *"PET_DETECTION"* ]]; then
        echo "  - Removing lib_pet_detection"
        rm -f "$PORT_DIR/system/system/lib64/lib_pet_detection.arcsoft.so"
    fi

    # libBestPhoto
    if ! grep -q "SUPPORT_SINGLE_TAKE_BURST_CAPTURE.*true" "$PORT_CAM/camera-feature.xml" 2>/dev/null; then
        echo "  - Removing libBestPhoto"
        rm -f "$PORT_DIR/system/system/lib64/libBestPhoto.camera.samsung.so"
    fi

    # aebhdr
    if [[ "$SRC_VLIB" == *"aebhdr.arcsoft.v1"* ]] && [[ "$TGT_VLIB" != *"aebhdr.arcsoft.v1"* ]]; then
        echo "  - Removing AEBHDR libs"
        rm -f "$PORT_DIR/system/system/lib64/libAEBHDR_wrapper.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libae_bracket_hdr.arcsoft.so"
    fi

    # dual bokeh
    if [ -f "$PORT_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" ] || \
       { [[ "$SRC_VLIB" == *"dual_bokeh.samsung"* ]] && [[ "$TGT_VLIB" != *"dual_bokeh.samsung"* ]]; }; then
        echo "  - Removing dual bokeh libs"
        rm -f "$PORT_DIR/system/system/lib64/libDualCamBokehCapture.camera.samsung.so"
        if [ ! -f "$PORT_DIR/system/system/lib64/libRelighting_API.camera.samsung.so" ]; then
            rm -f "$PORT_DIR/system/system/lib64/libarcsoft_dualcam_portraitlighting.so"
        fi
        if ! grep -q "GlassSegSDK" "$PORT_CAM/portrait_data/single_bokeh_feature.json" 2>/dev/null; then
            rm -f "$PORT_DIR/system/system/lib64/libarcsoft_single_cam_glasses_seg.so"
        fi
        rm -f "$PORT_DIR/system/system/lib64/libarcsoft_superresolution_bokeh.so"
        rm -f "$PORT_DIR/system/system/lib64/libdualcam_refocus_image.so"
        rm -f "$PORT_DIR/system/system/lib64/libhigh_dynamic_range_bokeh.so"
    fi

    # fusion/high_res
    if { [[ "$SRC_VLIB" == *"fusion_high_res.arcsoft.v1"* ]] && [[ "$TGT_VLIB" != *"fusion_high_res.arcsoft.v1"* ]]; } || \
       { [[ "$SRC_VLIB" == *"high_res.arcsoft.v2"* ]]         && [[ "$TGT_VLIB" != *"high_res.arcsoft.v2"* ]]; }; then
        echo "  - Removing high res enhancement libs"
        rm -f "$PORT_DIR/system/system/lib64/libHREnhancementAPI.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libhighres_enhancement.arcsoft.so"
    fi

    # fr_tracking
    if [[ "$SRC_VLIB" == *"fr_tracking.arcsoft.v1"* ]] && [[ "$TGT_VLIB" != *"fr_tracking.arcsoft.v1"* ]]; then
        echo "  - Removing face recognition tracking libs"
        rm -f "$PORT_DIR/system/system/lib64/libFaceRecognition.arcsoft.so"
        rm -f "$PORT_DIR/system/system/lib64/libfrtracking_engine.arcsoft.so"
    fi

    # hybridhdr
    if [[ "$SRC_VLIB" == *"hybridhdr.arcsoft.v1"* ]] && [[ "$TGT_VLIB" != *"hybridhdr.arcsoft.v1"* ]]; then
        echo "  - Removing hybrid HDR libs"
        rm -f "$PORT_DIR/system/system/lib64/libhybridHDR_wrapper.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libhybrid_high_dynamic_range.arcsoft.so"
    fi

    # image_enhance
    if [[ "$SRC_VLIB" == *"image_enhance.arcsoft.v1"* ]] && [[ "$TGT_VLIB" != *"image_enhance.arcsoft.v1"* ]]; then
        echo "  - Removing image enhancement lib"
        rm -f "$PORT_DIR/system/system/lib64/libimage_enhancement.arcsoft.so"
    fi

    # super_night MPI
    if [[ "$SRC_VLIB" == *"super_night.mpi.v2"* ]] && [[ "$TGT_VLIB" != *"super_night.mpi.v2"* ]]; then
        echo "  - Removing super night MPI libs"
        rm -f "$PORT_DIR/system/system/lib64/libAIQSolution_MPI.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libLocalTM_pcc.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libMultiFrameProcessing30.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libMultiFrameProcessing30.snapwrapper.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libMultiFrameProcessing30Tuning.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libObjectDetector_v1.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libSwIsp_core.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libSwIsp_wrapper_v1.camera.samsung.so"
    fi

    # super_resolution_raw
    if [[ "$SRC_VLIB" == *"super_resolution_raw.arcsoft"* ]] && [[ "$TGT_VLIB" != *"super_resolution_raw.arcsoft"* ]]; then
        echo "  - Removing super resolution raw libs"
        rm -f "$PORT_DIR/system/system/lib64/libsuperresolutionraw_wrapper_v2.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libsuperresolution_raw.arcsoft.so"
    fi

    # pro_single_rgb MPI
    if [[ "$SRC_VLIB" == *"pro_single_rgb.mpi.v1"* ]] && [[ "$TGT_VLIB" != *"pro_single_rgb.mpi.v1"* ]]; then
        echo "  - Removing MPI single RGB libs"
        rm -f "$PORT_DIR/system/system/lib64/libAIQSolution_MPISingleRGB40.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libMPISingleRGB40.camera.samsung.so"
        rm -f "$PORT_DIR/system/system/lib64/libMPISingleRGB40Tuning.camera.samsung.so"
    fi

    # scene_detection
    if [[ "$SRC_VLIB" == *"scene_detection.samsung.v1"* ]] && [[ "$TGT_VLIB" != *"scene_detection.samsung.v1"* ]]; then
        echo "  - Removing scene detection lib"
        rm -f "$PORT_DIR/system/system/lib64/libSceneDetector_v1.camera.samsung.so"
    fi

    # smart_scan
    if [[ "$SRC_VLIB" == *"smart_scan.samsung"* ]] && [[ "$TGT_VLIB" != *"smart_scan.samsung"* ]]; then
        echo "  - Removing smart scan lib"
        rm -f "$PORT_DIR/system/system/lib64/libSmartScan.camera.samsung.so"
    fi

    # ── 11. Document scan ─────────────────────────────────────────────────────
    local SRC_DOCSCAN TGT_DOCSCAN
    SRC_DOCSCAN="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_CAMERA_DOCUMENTSCAN_SOLUTIONS")"
    TGT_DOCSCAN="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_CAMERA_DOCUMENTSCAN_SOLUTIONS")"

    if [[ "$SRC_DOCSCAN" == *"AI_DEWARPING"* ]] && [[ "$TGT_DOCSCAN" != *"AI_DEWARPING"* ]]; then
        echo "  - Removing AI dewarping lib"
        rm -f "$PORT_DIR/system/system/lib64/libDeepDocRectify.camera.samsung.so"
    fi
    if [[ "$SRC_DOCSCAN" == *"SHADOW_REMOVAL"* ]] && [[ "$TGT_DOCSCAN" != *"SHADOW_REMOVAL"* ]]; then
        echo "  - Removing shadow removal lib"
        rm -f "$PORT_DIR/system/system/lib64/libDocShadowRemoval.arcsoft.so"
    fi

    # ── 12. Image segmenter ───────────────────────────────────────────────────
    if [ -f "$PORT_DIR/system/system/lib64/libImageSegmenter_v1.camera.samsung.so" ] && \
       [ ! -d "$PORT_DIR/vendor/etc/portrait_data/LF_segmenter" ]; then
        echo "  - Removing libImageSegmenter_v1"
        rm -f "$PORT_DIR/system/system/lib64/libImageSegmenter_v1.camera.samsung.so"
    fi

    # ── 12b. Fix object capture (OPCIONAL — só relevante para builds "essi" em
    #        devices específicos r0/g0/b0/a56*). Ative ENABLE_OBJECT_CAPTURE_FIX
    #        no topo da função só se souber que seu par doador/alvo se encaixa
    #        nesse caso; senão deixe desativado (padrão).
    if $ENABLE_OBJECT_CAPTURE_FIX; then
        local PORT_SYS_DEVICE PORT_VENDOR_DEVICE
        PORT_SYS_DEVICE="$(grep -m1 '^ro.product.device=' "$PORT_BUILD_PROP" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')"
        PORT_VENDOR_DEVICE="$(grep -m1 '^ro.product.vendor.device=' "$PORT_DIR/vendor/build.prop" 2>/dev/null | cut -d'=' -f2 | tr -d '\r')"

        if [[ "$PORT_SYS_DEVICE" =~ ^(r0|g0|b0) ]] && ! [[ "$PORT_VENDOR_DEVICE" =~ ^(r0|g0|b0) ]]; then
            echo "  - Patching object capture (r0/g0/b0 system/vendor mismatch)"
            HEX_PATCH "$PORT_DIR/system/system/lib64/libobjectcapture_jni.arcsoft.so" \
                "e503162a47020094e022009121008052e203162a" "8500805247020094e02200912100805282008052"
        elif ! [[ "$PORT_SYS_DEVICE" =~ ^(r0|g0|b0) ]] && [[ "$PORT_VENDOR_DEVICE" =~ ^(r0|g0|b0) ]]; then
            echo "  - Patching object capture (r0/g0/b0 vendor/system mismatch)"
            HEX_PATCH "$PORT_DIR/system/system/lib64/libobjectcapture_jni.arcsoft.so" \
                "e503162a47020094e022009121008052e203162a" "4500805247020094e02200912100805242008052"
        elif [[ "$PORT_SYS_DEVICE" != a56* ]] && [[ "$PORT_VENDOR_DEVICE" == a56* ]]; then
            echo "  - Patching object capture (a56 vendor/system mismatch)"
            HEX_PATCH "$PORT_DIR/system/system/lib64/libobjectcapture_jni.arcsoft.so" \
                "e503162a47020094e022009121008052e203162a" "c500805247020094e022009121008052c2008052"
        fi
    fi

    # ── 13. Fix portrait mode (libDualCamBokehCapture device check) ───────────
    if [ -f "$PORT_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" ]; then
        if grep -q "ro.build.flavor" "$PORT_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" 2>/dev/null; then
            echo "  - Patching portrait mode device check (ro.build.flavor prop)"
            local TARGET_BUILD_FLAVOR
            TARGET_BUILD_FLAVOR="$(grep -m1 '^ro.build.flavor=' \
                "$STOCK_BUILD_PROP" | cut -d'=' -f2 | tr -d '\r')"
            BUILD_PROP "$PORT_DIR" "system" "ro.build.flavor" "$TARGET_BUILD_FLAVOR"
        elif grep -q "ro.product.name" "$PORT_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" 2>/dev/null; then
            echo "  - Patching portrait mode device check (ro.product.name → ro.unica.camera)"
            HEX_PATCH "$PORT_DIR/vendor/lib/libDualCamBokehCapture.camera.samsung.so" \
                "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
            HEX_PATCH "$PORT_DIR/vendor/lib/liblivefocus_capture_engine.so" \
                "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
            HEX_PATCH "$PORT_DIR/vendor/lib/liblivefocus_preview_engine.so" \
                "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
            HEX_PATCH "$PORT_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" \
                "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
            HEX_PATCH "$PORT_DIR/vendor/lib64/liblivefocus_capture_engine.so" \
                "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
            HEX_PATCH "$PORT_DIR/vendor/lib64/liblivefocus_preview_engine.so" \
                "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
            # camera fix
            HEX_PATCH "$PORT_DIR/system/system/lib64/libstagefright.so" \
        "02408052e30314aae41f8052" "e21f8052e30314aae41f8052"    

            # Add selinux property context
            echo "ro.unica.camera u:object_r:build_prop:s0 exact string" \
                >> "$PORT_DIR/system/system/etc/selinux/plat_property_contexts"

            # Set the prop to the target's product name
            local TARGET_PRODUCT_NAME
            TARGET_PRODUCT_NAME="$(grep -m1 '^ro.product.system.name=' \
                "$PORT_DIR/system/system/build.prop" | cut -d'=' -f2 | tr -d '\r')"
            BUILD_PROP "$PORT_DIR" "system" "ro.unica.camera" "$TARGET_PRODUCT_NAME"
        fi
    fi

    # ── 14. Gallery PetService ────────────────────────────────────────────────
    local SRC_PET TGT_PET
    SRC_PET="$(GET_FLOATING_FEATURE_CONFIG \
        "SEC_FLOATING_FEATURE_GALLERY_CONFIG_PET_CLUSTER_VERSION")"
    TGT_PET="$(GET_TARGET_FLOATING_FEATURE \
        "SEC_FLOATING_FEATURE_GALLERY_CONFIG_PET_CLUSTER_VERSION")"

    if [[ "$SRC_PET" != "None" ]] && [[ "$TGT_PET" == "None" ]]; then
        echo "  - Removing PetService"
        rm -f "$PORT_DIR/system/system/etc/default-permissions/default-permissions-com.samsung.petservice.xml"
        rm -f "$PORT_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.petservice.xml"
        rm -f "$PORT_DIR/system/system/lib64/libPetClustering.camera.samsung.so"
        rm -rf "$PORT_DIR/system/system/priv-app/PetService"
    fi

    # ── 15. Camera cutout protection (OPCIONAL) ───────────────────────────────
    # TODO: no original, SOURCE/TARGET_CAMERA_SUPPORT_CUTOUT_PROTECTION são
    # booleanos vindos de fora deste arquivo (não do floating_feature.xml) —
    # eu não sei como seu sistema determina isso. Defina a lógica real abaixo
    # antes de ativar ENABLE_CUTOUT_PROTECTION_FIX no topo da função.
    if $ENABLE_CUTOUT_PROTECTION_FIX; then
        if [ ! "$(find "$SYSTEMUI_OVERLAY_DIR" -maxdepth 1 -type f -name "SystemUI*" 2>/dev/null)" ]; then
            local SOURCE_CUTOUT="" TARGET_CUTOUT=""   # TODO: preencher com sua lógica real
            if [[ "$SOURCE_CUTOUT" != "$TARGET_CUTOUT" ]]; then
                echo "  - Patching SystemUI cutout protection ($SOURCE_CUTOUT -> $TARGET_CUTOUT)"
                "$APKTOOL" d -f -o "$WORK_DIR/systemui_tmp" \
                    "$PORT_DIR/system_ext/priv-app/SystemUI/SystemUI.apk"
                sed -i "s/config_enableDisplayCutoutProtection\">$SOURCE_CUTOUT/config_enableDisplayCutoutProtection\">$TARGET_CUTOUT/" \
                    "$WORK_DIR/systemui_tmp/res/values/bools.xml"
                "$APKTOOL" b -f -o "$PORT_DIR/system_ext/priv-app/SystemUI/SystemUI.apk" \
                    "$WORK_DIR/systemui_tmp"
                rm -rf "$WORK_DIR/systemui_tmp"
            fi
        fi
    fi

    echo "  - Camera patch done."
}
