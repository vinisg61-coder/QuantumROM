#!/bin/bash

if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX> <TARGET_DEVICE> <TARGET_DEVICE_CSC> <TARGET_DEVICE_IMEI> <OUTPUT_FILESYSTEM>"
    exit 1
fi

# Device info
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"
export TARGET_DEVICE="$3"
export TARGET_DEVICE_CSC="$4"
export TARGET_DEVICE_IMEI="$5"
export OUTPUT_FILESYSTEM="$6"

# Respect a target-specific default filesystem when declared in its device config.
# This keeps the original workflow override for other targets while ensuring
# SM-A528B/a52sxq uses the ext4 format required by its stock early-mount fstab.
DEVICE_CONFIG="$(pwd)/QuantumROM/Devices/${STOCK_DEVICE}/config"
if [ -f "$DEVICE_CONFIG" ]; then
    TARGET_DEFAULT_IMG_TYPE="$(grep -m1 '^default_img_type=' "$DEVICE_CONFIG" | cut -d= -f2- | tr -d '\"' | xargs)"
    if [ -n "$TARGET_DEFAULT_IMG_TYPE" ]; then
        echo "[TARGET] ${STOCK_DEVICE}: forcing OUTPUT_FILESYSTEM=${TARGET_DEFAULT_IMG_TYPE} from ${DEVICE_CONFIG}"
        export OUTPUT_FILESYSTEM="$TARGET_DEFAULT_IMG_TYPE"
    fi
fi

VERSION="1"

# Directories
export FIRM_DIR="$(pwd)/FW"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export APKTOOL="$(pwd)/bin/java/apktool.jar"
export DEVICES_DIR="$(pwd)/QuantumROM/Devices"
export VNDKS_COLLECTION="$(pwd)/QuantumROM/vndks"
export PATCHES_DIR="$(pwd)/QuantumROM/patches"
export BUILD_PARTITIONS="product,system_ext,system,vendor,odm"
if grep -q '^STOCK_HAS_SEPARATE_SYSTEM_EXT=FALSE' "$DEVICE_CONFIG"; then
    export BUILD_PARTITIONS="product,system,vendor,odm"
    echo "[TARGET] ${STOCK_DEVICE}: using merged system_ext layout; BUILD_PARTITIONS=${BUILD_PARTITIONS}"
fi

# Source
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/QuantumRom.sh"

EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"

OVERRIDE_STOCK_VENDOR_ODM "$FIRM_DIR/$TARGET_DEVICE"

EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"
PATCH_CODEC2_SECCOMP "$FIRM_DIR/$TARGET_DEVICE"

APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"

# SM-A528B stock 5.4 compatibility: prevent donor schedtune/cgroup setup
# from making apexd-bootstrap fatal before Android userspace starts.
if [ "$STOCK_DEVICE" = "SM-A528B" ]; then
    python3 "$(pwd)/scripts/patch_a52sxq_compat.py" \
        "$FIRM_DIR/$TARGET_DEVICE" \
        "$STOCK_DEVICE"
fi

if [ "$STOCK_DEVICE" = "SM-A528B" ]; then
    python3 "$(pwd)/scripts/patch_a52sxq_camera_binary.py" \
        "$FIRM_DIR/$TARGET_DEVICE" \
        "$STOCK_DEVICE"
fi

PATCH_A52SXQ_CAMERA_CONFIG "$FIRM_DIR/$TARGET_DEVICE"

# A52s Wi-Fi resource RRO: disable donor-only 6 GHz/802.11be/bridged AP
# capability flags while preserving the native HIDL HAL and vendor blobs.
if [ "$STOCK_DEVICE" = "SM-A528B" ]; then
    python3 "$(pwd)/scripts/patch_a52sxq_wifi_resources.py" \
        "$FIRM_DIR/$TARGET_DEVICE" \
        "$STOCK_DEVICE" \
        "$APKTOOL" \
        "$WORK_DIR"
fi

# SM-A528B native Qualcomm WLAN interface map: keep STA on wlan0 and
# expose the native concurrent/AP and auxiliary interfaces to the donor framework.
# This is target-only and does not replace vendor Wi-Fi HAL or firmware blobs.
if [ "$STOCK_DEVICE" = "SM-A528B" ]; then
    BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "wifi.concurrent.interface" "swlan0"
    BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "wifi.direct.interface" "p2p0"
    BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "wifi.aware.interface" "wifi-aware0"
fi

PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SYSTEM_EXT_VINTF "$FIRM_DIR/$TARGET_DEVICE"
ENABLE_DEBUG_PORT "$FIRM_DIR/$TARGET_DEVICE" 
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
ADD_KERNELSU_NEXT "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"
PATCH_VENDOR_INIT "$FIRM_DIR/$TARGET_DEVICE"

INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"

PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_KNOX_GUARD "$WORK_DIR/services" 
PATCH_FACTORY_TEST "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
APPLY_PATCH "$WORK_DIR/services" "$PATCHES_DIR/0001-Fix-FOD-brightness-scaling-in-getAlphaMaskLevel.patch" 
PATCH_PRIVATE_SHARE "$WORK_DIR/samsungkeystoreutils"

RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"
mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"
PATCH_SAMSUNG_CAMERA_LIBS "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SYSTEM_NFC_STACK "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"

B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
B_V="$(grep -m1 '^ro.system.build.version.incremental=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "QuantumROM Aurora - 1.0.0 (${B_ID}.${B_V})"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "QuantumROM Aurora - 1.0.0 (${B_ID}.${B_V})"

BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
if ! BUILD_SUPER_IMG "$OUT_DIR" "$OUT_DIR"; then
    echo "- Failed to build a valid super.img; aborting before flashable ZIP packaging."
    exit 1
fi

# Clean up stock vendor/odm images from firmware dir (already built to OUT)
rm -f "$FIRM_DIR/$TARGET_DEVICE/vendor.img" "$FIRM_DIR/$TARGET_DEVICE/odm.img"
