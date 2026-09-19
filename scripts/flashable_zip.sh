#!/usr/bin/env bash
# =============================================================================
#  QuantumROM — flashable_zip.sh
#  Generates a flashable zip containing super.img, boot.img, and dtbo.img.
#
#  Called by build_quantum.sh after a successful build.
#  Required exported vars:
#    QT_DIR        → root of the QuantumROM repo
#    DEVICES_DIR   → path to device configs
#    STOCK_DEVICE  → stock device model (e.g. SM-G980F)
#    TARGET_DEVICE → target device model (e.g. SM-A346E)
#    OUT_DIR       → build output directory
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()   { echo -e "${CYAN}[FLASH]${RESET} $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; return 1; }

# ── Configurações de Versão e Codinome ────────────────────────────────────────
export ROM_CODENAME="Aurora"
export ROM_VER_MAJOR="1"
export ROM_VER_MINOR="0"
export ROM_VER_PATCH="0"

# Monta a versão completa no formato 1.0.0
export ROM_VERSION="${ROM_VER_MAJOR}.${ROM_VER_MINOR}.${ROM_VER_PATCH}"
export ONEUI_VERSION="8.5"

# ── Resolve paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QT_DIR="${QT_DIR:-$(dirname "$SCRIPT_DIR")}"
DEVICES_DIR="${DEVICES_DIR:-$QT_DIR/QuantumROM/Devices}"
OUT_DIR="${OUT_DIR:-$QT_DIR/OUT}"

if [[ -z "${STOCK_DEVICE:-}" ]]; then
    die "STOCK_DEVICE is not set." || return 1
fi

if [[ -z "${TARGET_DEVICE:-}" ]]; then
    die "TARGET_DEVICE is not set." || return 1
fi

DEVICE_DIR="$DEVICES_DIR/$STOCK_DEVICE"
EXTRA_DIR="$DEVICE_DIR/extra"
TODAY="${ZIP_DATE:-$(date '+%Y%m%d')}"

# Nome do ZIP com a estrutura do QuantumROM
ZIP_NAME="QuantumROM-${ROM_CODENAME}_${ROM_VERSION}_${STOCK_DEVICE}_${TODAY}.zip"
FINAL_ZIP="$OUT_DIR/$ZIP_NAME"

# Staging dir — META-INF deve existir aqui
STAGING="$QT_DIR/QuantumROM/flashable_zip"

# ── Cleanup on exit ───────────────────────────────────────────────────────────
trap 'echo -e "${YELLOW}[WARN]${RESET}  Interrupted — staging left as-is for inspection."' INT

# ── Check dependencies ────────────────────────────────────────────────────────
log "Checking dependencies..."
for cmd in 7z; do
    if ! command -v "$cmd" &>/dev/null; then
        die "Required tool not found: $cmd" || return 1
    fi
done

# ── Sanity checks ─────────────────────────────────────────────────────────────
log "Starting flashable zip generation..."
log "  ROM Codename  : $ROM_CODENAME"
log "  ROM Version   : $ROM_VERSION (Major: $ROM_VER_MAJOR, Minor: $ROM_VER_MINOR, Patch: $ROM_VER_PATCH)"
log "  Stock device  : $STOCK_DEVICE"
log "  Target device : $TARGET_DEVICE"
log "  Extra dir     : $EXTRA_DIR"
log "  Output        : $FINAL_ZIP"
echo ""

[[ -d "$DEVICE_DIR" ]] || { die "Device directory not found: $DEVICE_DIR" || return 1; }
[[ -d "$EXTRA_DIR"  ]] || { die "Extra directory not found: $EXTRA_DIR" || return 1; }
if [[ ! -d "$STAGING/META-INF" ]]; then
    die "META-INF not found in staging dir: $STAGING/META-INF" || return 1
fi

# ── Clean previous build artifacts from staging ───────────────────────────────
log "Cleaning up leftover image files in staging..."
find "$STAGING" -maxdepth 1 -type f \( \
    -name "*.img" -o \
    -name "*.dat" -o \
    -name "*.dat.br" -o \
    -name "*.list" \
\) -delete
ok "Staging directory clean."

# ── Copy super.img from OUT_DIR ───────────────────────────────────────────────
SUPER_IMG="$OUT_DIR/super.img"
[[ -f "$SUPER_IMG" ]] || { die "super.img not found at $SUPER_IMG! Build super.img first." || return 1; }

log "Copying super.img from OUT_DIR..."
cp -f "$SUPER_IMG" "$STAGING/super.img"
ok "super.img successfully copied to staging."

# ── Copy boot and dtbo ────────────────────────────────────────────────────────
log "Looking for boot-dtbo zip in $EXTRA_DIR ..."
BOOT_DTBO_ZIP="$(find "$EXTRA_DIR" -maxdepth 2 -type f -name "boot-dtbo.*.zip" | head -n1)"
[[ -n "$BOOT_DTBO_ZIP" ]] || { die "No boot-dtbo.<codename>.zip found inside $EXTRA_DIR" || return 1; }
ok "Found: $(basename "$BOOT_DTBO_ZIP")"

log "Extracting boot.img and dtbo.img..."
BOOT_TMP="$(mktemp -d)"

7z e -y "$BOOT_DTBO_ZIP" -o"$BOOT_TMP" boot.img dtbo.img >/dev/null 2>&1 || \
    unzip -o "$BOOT_DTBO_ZIP" boot.img dtbo.img -d "$BOOT_TMP" >/dev/null 2>&1

if [[ ! -f "$BOOT_TMP/boot.img" ]] || [[ ! -f "$BOOT_TMP/dtbo.img" ]]; then
    rm -rf "$BOOT_TMP"
    die "boot.img or dtbo.img not found inside $(basename "$BOOT_DTBO_ZIP")" || return 1
fi

cp -f "$BOOT_TMP/boot.img" "$STAGING/boot.img"
cp -f "$BOOT_TMP/dtbo.img" "$STAGING/dtbo.img"
rm -rf "$BOOT_TMP"
ok "boot.img and dtbo.img copied to staging."

# ── Generate updater-script ───────────────────────────────────────────────────
log "Generating updater-script..."
mkdir -p "$STAGING/META-INF/com/google/android"
SCRIPT_FILE="$STAGING/META-INF/com/google/android/updater-script"

# Prevenção: Força a criação do arquivo limpo
> "$SCRIPT_FILE"

# Preenche o updater-script
cat > "$SCRIPT_FILE" << EOF
ui_print(" ");
ui_print("****************************************************");
ui_print("Welcome to QuantumROM ${ROM_CODENAME} v${ROM_VERSION}!");
ui_print("Initial QuantumROM build system coded by Abdullah Al Noman");
ui_print("Special thanks to all QuantumROM Maintainers, Contribuitors and Testers");
ui_print("****************************************************");
ui_print("One UI version: ${ONEUI_VERSION}");
ui_print("****************************************************");
ui_print("After installation, it is highly recommended to FORMAT DATA as follows:");
ui_print("     Wipe -> Format Data");
ui_print("Hint: FORMAT, not WIPE or FACTORY RESET!");
ui_print(" ");
ui_print("If you decide to not format, unexpected issues may occur and given support will be limited.");
ui_print(" ");
ui_print("If you wish to proceed with the installer, please press the Volume UP button.");
ui_print("Otherwise, hold the Volume DOWN + POWER buttons for 7 seconds to force reboot.");

assert(run_program("/sbin/sh", "-c", "while true; do getevent -lc 1 | grep -q -m1 'KEY_VOLUMEUP' && exit 0; sleep 1; done"));

ui_print(" ");
ui_print("Proceeding...!");
ui_print(" ");
ui_print("****************************************************");
ui_print("       Q U A N T U M ---- R O M !");
ui_print("****************************************************");
ui_print("--Installing QuantumROM ${ROM_CODENAME}");
show_progress(0.900000, 0);
package_extract_file("super.img", "/dev/block/bootdevice/by-name/super");
show_progress(0.100000, 0);
ui_print("--Flashing boot and dtbo...");
package_extract_file("dtbo.img", "/dev/block/bootdevice/by-name/dtbo");
package_extract_file("boot.img", "/dev/block/bootdevice/by-name/boot");
set_progress(1.000000);
ui_print(" ");
ui_print("Thanks for flashing, enjoy the ROM!");
ui_print("****************************************************");
ui_print(" ");
EOF

ok "updater-script generated"

# ── Staging summary ───────────────────────────────────────────────────────────
echo ""
log "Flashable zip contents:"
for f in "$STAGING"/*; do
    sz="$(du -sh "$f" 2>/dev/null | cut -f1)"
    echo -e "  ${BOLD}$(basename "$f")${RESET}  ($sz)"
done
echo ""

# ── Pack into final zip ───────────────────────────────────────────────────────
log "Packing $ZIP_NAME ..."
mkdir -p "$OUT_DIR"
ROM_ZIP_TMP="$STAGING/rom.zip"
rm -f "$ROM_ZIP_TMP" "$FINAL_ZIP"

cd "$STAGING" || { die "Failed to enter $STAGING" || return 1; }

# Store META-INF sem compressão
7z a -tzip -mx=0 -mmt="$(nproc)" "$ROM_ZIP_TMP" \
    -ir!"META-INF/com/google/android/*" 2>/dev/null || true

# Compacta os arquivos restantes
7z a -tzip -mx=1 -mmt="$(nproc)" "$ROM_ZIP_TMP" \
    -r "*" \
    -xr!"META-INF/com/google/android/*" \
    -x!"rom.zip"
cd - >/dev/null

mv -f "$ROM_ZIP_TMP" "$FINAL_ZIP"

ok "Flashable zip ready → $FINAL_ZIP"
echo -e "${BOLD}${GREEN}✅ flashable_zip.sh done! → $FINAL_ZIP${RESET}"

# Remove o trap de interrupção ao finalizar com sucesso
trap - INT
