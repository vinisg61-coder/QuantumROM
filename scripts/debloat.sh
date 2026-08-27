#!/bin/bash
# =============================================================================
#  QuantumROM — debloat.sh (Galaxy AI, Messages & Velvet Preserved)
# =============================================================================
if [ -n "${DEVICES_DIR:-}" ] && [ -n "${STOCK_DEVICE:-}" ] && [ -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
    source "$DEVICES_DIR/$STOCK_DEVICE/config"
else
    echo "[WARN] Target config not found while sourcing debloat settings: ${DEVICES_DIR:-<unset>}/${STOCK_DEVICE:-<unset>}/config"
fi
# ── Helpers ───────────────────────────────────────────────────────────────────

KICK() {
    if [ "$#" -lt 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <APPS...>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    shift
    local APPS_LIST=("$@")

    local APP_DIRS=(
        "$EXTRACTED_FIRM_DIR/system/system/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/product/app"
        "$EXTRACTED_FIRM_DIR/product/priv-app"
    )

    for app in "${APPS_LIST[@]}"; do
        for dir in "${APP_DIRS[@]}"; do
            local target="$dir/$app"
            if [[ -d "$target" ]]; then
                rm -rf "$target" || echo -e "[WARN] Failed to delete $target"
            fi
        done
    done
}

REMOVE_ESIM_FILES() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing ESIM files."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/autoinstalls/autoinstalls-com.google.android.euicc"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/default-permissions/default-permissions-com.google.android.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimClient"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimKeyString"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccService"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccGoogle"
}

REMOVE_FABRIC_CRYPTO() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing fabric crypto."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/bin/fabric_crypto"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/fabric_crypto.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/FabricCryptoLib.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.odex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.vdex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.odex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.vdex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/KmxService"
}

# ── Atomic debloat ────────────────────────────────────────────────────────────

DEBLOAT() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local TARGET_DIR="$1"
    echo "- Running Atomic Debloat Process (Tks mecyanned)..."

    local TARGET_ROM_SYSTEM_EXT_DIR="$(GET_SYSTEM_EXT_DIR "$TARGET_DIR")"

    quantum_remove() {
        local part="$1"
        local path="$2"
        local full_path=""

        if [ "$part" = "system" ]; then
            full_path="${TARGET_DIR}/system/system/${path}"
        elif [ "$part" = "system_ext" ] && [ -n "$TARGET_ROM_SYSTEM_EXT_DIR" ]; then
            full_path="${TARGET_ROM_SYSTEM_EXT_DIR}/${path}"
        else
            full_path="${TARGET_DIR}/${part}/${path}"
        fi

        if [ -e "$full_path" ] || [ -L "$full_path" ]; then
            rm -rf "$full_path"
        fi
    }

    # ── 1. Deep cache cleanup (odex / vdex / art / oat) ──────────────────────
    find "${TARGET_DIR}/system/system/" -type f \( -name "*.odex" -o -name "*.vdex" -o -name "*.art" -o -name "*.oat" \) -delete >/dev/null 2>&1
    find "${TARGET_DIR}/system/system/" \( -type f \( -name "*.odex" -o -name "*.vdex" -o -name "*.art" -o -name "*.oat" \) -o -type d -name "oat" \) -exec rm -rf {} + >/dev/null 2>&1
    find "${TARGET_DIR}/product/" \( -type f \( -name "*.odex" -o -name "*.vdex" -o -name "*.art" -o -name "*.oat" \) -o -type d -name "oat" \) -exec rm -rf {} + >/dev/null 2>&1

    # ── 2. Ghost folders & misc files ────────────────────────────────────────
    quantum_remove "system" "hidden"
    quantum_remove "system" "skt"
    quantum_remove "system" "tts"
    quantum_remove "system" "etc/mediasearch"
    quantum_remove "system" "priv-app/MediaSearch"
    quantum_remove "system" "etc/init/boot-image.bprof"
    quantum_remove "system" "etc/init/boot-image.prof"

    # Truncate vpl list
    if [ -f "${TARGET_DIR}/system/system/etc/vpl_apks_count_list.txt" ]; then
        truncate -s 0 "${TARGET_DIR}/system/system/etc/vpl_apks_count_list.txt"
    fi

    # Delete survey mode from floating_feature
    if [ -f "${TARGET_DIR}/customer/floating_feature.xml" ]; then
        sed -i '/SEC_FLOATING_FEATURE_CONTEXTSERVICE_ENABLE_SURVEY_MODE/d' "${TARGET_DIR}/customer/floating_feature.xml"
    fi

    # ── 3. Fabric Crypto ─────────────────────────────────────────────────────
    REMOVE_FABRIC_CRYPTO "$TARGET_DIR"

    # ── 4. Build bloat target list ────────────────────────────────────────────
    declare -a BLOAT_TARGETS=()

    # General bloatware and trackers
    # Mantidos do Galaxy AI: SumeNNService, vexfwk_service
    BLOAT_TARGETS+=(
        "ccinfo" "EasySetup" "MyDevice" "NSDSWebApp"
        "NSFusedLocation_v6.0" "SmartSwitchAgent" "SmartSwitchStub" "AASAservice"
        "DckTimeSyncService" "EnhancedAttestationAgent" "HdmApk"
        "MCFDeviceSync" "Moments" "OdaService" "PrivateAccessTokens" "SafetyInformation"
        "SDMConfig"
        # from original
        "HMT" "DigitalWellbeing" "FactoryCameraFB" "WlanTest" "AirGlance"
        "AirReadingGlass" "AndroidGlassesCore" "SOAgent77" "ARCore" "ARDrawing"
        "ARZone" "BGMProvider" "SingleTakeService" "BixbyWakeup" "Fast" "FunModeSDK"
        "KidsHome_Installer" "LinkSharing_v11" "MdecService" "MoccaMobile"
        "Netflix_stub" "PhotoTable" "UnifiedWFC" "VideoEditorLite_Dream_N"
        "VTCameraSetting" "WifiGuider" "CIDManager"
        "serviceModeApp_FB" "EarphoneTypeC" "HashTagService" "MemorySaver_O_Refresh"
        "MultiControl" "MultiControlVP6" "OMCAgent5" "OneStoreService" "SOAgent7"
        "SOAgent75" "SolarAudio-service" "TADownloader" "TalkbackSE"
        "TaPackAuthFw" "UltraDataSaving_O" "Upday" "YourPhone_P1_5"
        "VexScanner"
        # Kept: LiveEffectService, LiveDrawing, StoryService, GalleryWidget,
        #       AutoDoodle, AvatarEmojiSticker, AvatarEmojiSticker_S, AvatarPicker,
        #       LiveStickers, sticker — Galaxy AI / wallpaper / photo editor features
        "AirCommand"
        "Duo" "Photos" "AndroidDeveloperVerifier" "YourPhone_Stub"
        "AndroidAutoStub" "GoogleRestore"
    )

    # Samsung TTS voice packs
    BLOAT_TARGETS+=(
        "SamsungTTS" "SamsungBilling"
        "SamsungTTSVoice_de_DE_f00" "SamsungTTSVoice_en_GB_f00" "SamsungTTSVoice_en_US_l03"
        "SamsungTTSVoice_es_ES_f00" "SamsungTTSVoice_es_MX_f00" "SamsungTTSVoice_es_US_f00"
        "SamsungTTSVoice_es_US_l01" "SamsungTTSVoice_fr_FR_f00" "SamsungTTSVoice_hi_IN_f00"
        "SamsungTTSVoice_it_IT_f00" "SamsungTTSVoice_pl_PL_f00" "SamsungTTSVoice_pt_BR_f00"
        "SamsungTTSVoice_pt_BR_l01" "SamsungTTSVoice_ru_RU_f00" "SamsungTTSVoice_th_TH_f00"
        "SamsungTTSVoice_vi_VN_f00" "SamsungTTSVoice_id_ID_f00" "SamsungTTSVoice_ar_AE_m00"
        "SamsungTTSVoice_zh_TW_f00" "SamsungTTSVoice_zh_HK_f00" "SamsungTTSVoice_zh_CN_l02"
    )
    rm -rf "${TARGET_DIR}/system/system/app"/SamsungTTS*

    # Knox / carrier analytics
    BLOAT_TARGETS+=(
        "KnoxFrameBufferProvider" "KnoxGuard" "Rampart" "knoxanalyticsagent"
        "KnoxERAgent" "KnoxMposAgent" "KnoxPushManager" "KPECore" "KLMSAgent"
        "MDMApp" "UniversalMDMClient"
    )

    # Intelligent Dynamic FPS (conditional)
    if [[ "${DEBLOAT_REMOVE_HFR_SERVICE:-false}" == "true" ]]; then
        BLOAT_TARGETS+=("IntelligentDynamicFpsService")
    fi

    # eSIM (conditional)
    if [[ "${DEBLOAT_REMOVE_ESIM:-false}" == "true" ]]; then
        BLOAT_TARGETS+=("EsimKeyString" "EuiccService")
        quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
        quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.euicc.xml"
        quantum_remove "system" "etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
        quantum_remove "system" "etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
    fi

    # Miscellaneous useless system services
    BLOAT_TARGETS+=(
        "MAPSAgent" "AppUpdateCenter" "BCService" "UnifiedVVM" "UnifiedTetheringProvision"
        "UsByod" "WebManual" "DictDiotekForSec" "VzCloud"
        "OmcAgent5" "SetupWizardLegalProvider" "SPPPushClient" "HiyaService"
        # from original
        "Discover" "DiscoverSEP" "FotaAgent" "LinkToWindowsService"
        "SolarAudio-service" "SwiftkeyIme" "SwiftkeySetting" "SystemUpdate"
    )
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.app.updatecenter.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.sec.bcservice.xml"
    quantum_remove "vendor" "etc/dpolicy"
    quantum_remove "system" "dpolicy_system"

    # Game Hub and redundant Snapdragon drivers
    BLOAT_TARGETS+=(
        "GameHome"
        "GameDriver-SM8350" "GameDriver-SM8450" "GameDriver-SM8550" "GameDriver-SM8650"
        "DevGPUDriver-EX2200" "GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150"
    )
    rm -rf "${TARGET_DIR}/system/system/priv-app"/GameDriver-*
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.game.gamehome.xml"
    quantum_remove "system" "etc/permissions/signature-permissions-com.samsung.android.game.gamehome.xml"

    # Telemetry-heavy Google apps & stubs
    # Preservados para IA / Mensagens: Velvet
    BLOAT_TARGETS+=(
        "Gmail2" "Chrome" "DuoStub" "Maps"
        "PlayAutoInstallConfig" "YouTube"
        "ChromeCustomizations"
        "com.google.mainline.adservices" "com.google.mainline.telemetry"
        "GoogleFeedback" "GoogleLocationHistory"
        "GoogleCalendarSyncAdapter" "FamilyLinkParentalControls"
    )
    rm -rf "${TARGET_DIR}/product/app/Gmail2/oat"
    rm -rf "${TARGET_DIR}/product/app/Maps/oat"
    rm -rf "${TARGET_DIR}/product/app/YouTube/oat"
    quantum_remove "product" "overlay/GmsConfigOverlaySearchSelector.apk"

    # Samsung factory & hardware test tools
    BLOAT_TARGETS+=(
        "Cameralyzer" "FactoryAirCommandManager" "FactoryCameraFB" "HMT" "WlanTest"
        "FacAtFunction" "FactoryTestProvider" "AutomationTest_FB" "DRParser"
        "SEMFactoryApp" "UwbTest" "sec_camerax_service" "SmartEpdgTestApp" "NetworkDiagnostic"
    )
    quantum_remove "system" "etc/default-permissions/default-permissions-com.sec.factory.cameralyzer.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.providers.factory.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.sec.facatfunction.xml"

    # NFC LED Cover (conditional)
    if [[ "${DEBLOAT_REMOVE_NFC_LED_COVER:-false}" == "true" ]]; then
        BLOAT_TARGETS+=("LedCoverService")
        quantum_remove "system" "etc/permissions/privapp-permissions-com.sec.android.cover.ledcover.xml"
    fi

    # Extra accessibility tools
    BLOAT_TARGETS+=("LiveTranscribe" "VoiceAccess")
    quantum_remove "system" "etc/sysconfig/feature-a11y-preload.xml"
    quantum_remove "system" "etc/sysconfig/feature-a11y-preload-voacc.xml"

    # Meta / Facebook
    BLOAT_TARGETS+=("FBAppManager_NS" "FBInstaller_NS" "FBServices")
    quantum_remove "system" "etc/default-permissions/default-permissions-meta.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-meta.xml"
    quantum_remove "system" "etc/sysconfig/meta-hiddenapi-package-allowlist.xml"

    # Microsoft OneDrive stub
    BLOAT_TARGETS+=("OneDrive_Samsung_v3")
    quantum_remove "system" "etc/permissions/privapp-permissions-com.microsoft.skydrive.xml"

    # Samsung analytics & telemetry
    BLOAT_TARGETS+=("MyGalaxyService" "DsmsAPK" "DeviceQualityAgent36" "DiagMonAgent95" "DiagMonAgent91" "SOAgent76")
    quantum_remove "system" "etc/permissions/privapp-permissions-com.mygalaxy.service.xml"
    quantum_remove "system" "etc/sysconfig/preinstalled-packages-com.mygalaxy.service.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.dqagent.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.sec.android.diagmonagent.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.sec.soagent.xml"

    # Samsung AR Emoji — kept AREmojiEditor and AvatarEmojiSticker (Galaxy AI / photo editor)
    # Only removing the sticker packs permission XMLs that are unused without the full suite
    quantum_remove "system" "etc/default-permissions/default-permissions-com.sec.android.mimage.avatarstickers.xml"
    quantum_remove "system" "etc/permissions/signature-permissions-com.sec.android.mimage.avatarstickers.xml"

    # Heavy Samsung user apps
    # Removido do debloat: OfflineLanguageModel_stub, AndroidSystemIntelligence, SamsungSmartSuggestions
    BLOAT_TARGETS+=(
        "SamsungCalendar" "ClockPackage" "MinusOnePage" "SmartReminder"
        "Notes40" "SBrowser" "DigitalWellbeing" "GearManagerStub"
    )

    # Samsung Pass & biometric security
    BLOAT_TARGETS+=("SamsungPassAutofill_v1" "AuthFramework" "SamsungPass")
    quantum_remove "system" "etc/init/samsung_pass_authenticator_service.rc"
    quantum_remove "system" "etc/permissions/authfw.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.authfw.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.samsungpass.xml"
    quantum_remove "system" "etc/permissions/signature-permissions-com.samsung.android.samsungpass.xml"
    quantum_remove "system" "etc/permissions/signature-permissions-com.samsung.android.samsungpassautofill.xml"
    quantum_remove "system" "etc/sysconfig/samsungauthframework.xml"
    quantum_remove "system" "etc/sysconfig/samsungpassapp.xml"

    # Samsung Wallet / Pay / Digital Key (broken on Knox 0x1)
    BLOAT_TARGETS+=("IpsGeofence" "DigitalKey" "PaymentFramework" "SamsungCarKeyFw" "SamsungWallet" "BlockchainBasicKit")
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.ipsgeofence.xml"
    quantum_remove "system" "com.samsung.feature.ipsgeofence.xml"
    quantum_remove "system" "etc/init/digitalkey_init_ble_tss2.rc"
    quantum_remove "system" "etc/permissions/org.carconnectivity.android.digitalkey.rangingintent.xml"
    quantum_remove "system" "etc/permissions/org.carconnectivity.android.digitalkey.secureelement.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.carkey.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.dkey.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.spayfw.xml"
    quantum_remove "system" "etc/permissions/signature-permissions-com.samsung.android.spay.xml"
    quantum_remove "system" "etc/permissions/signature-permissions-com.samsung.android.spayfw.xml"
    quantum_remove "system" "etc/sysconfig/digitalkey.xml"
    quantum_remove "system" "etc/sysconfig/preinstalled-packages-com.samsung.android.dkey.xml"
    quantum_remove "system" "etc/sysconfig/preinstalled-packages-com.samsung.android.spayfw.xml"
    quantum_remove "system_ext" "framework/org.carconnectivity.android.digitalkey.rangingintent.jar"
    quantum_remove "system_ext" "framework/org.carconnectivity.android.digitalkey.secureelement.jar"

    # Redundant utilities & background services
    BLOAT_TARGETS+=(
        "SearchSelector" "SHClient" "SmartTouchCall" "SmartTutor" "FotaAgent"
        "SVCAgent" "SVoiceIME" "wssyncmldm" "GameOptimizingService"
        "GooglePrintRecommendationService" "PrivacyDashboard" "ParentalCare"
        "ImsLogger" "EarthquakeWarning" "StickerCenter"
    )

    # Korean carrier apps
    BLOAT_TARGETS+=(
        "KTAuth" "KTCustomerService" "KTUsimManager"
        "LGUMiniCustomerCenter" "LGUplusTsmProxy"
        "SKTMemberShip_new" "SktUsimService" "TWorld"
        "KT114Provider2" "KTHiddenMenu" "KTOneStore"
        "KTServiceAgent" "KTServiceMenu"
        "LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore"
        "SKTFindLostPhone" "SKTHiddenMenu" "SKTMemberShip"
        "SKTOneStore" "SKTFindLostPhoneApp"
        "TPhoneOnePackage" "TPhoneSetup" "TService"
        "UsimRegistrationKOR" "HpsAgreement_new" "KTAuth_Stub"
    )

    # Mainland China bloatware
    BLOAT_TARGETS+=(
        "TencentWifiSecurity" "TNCPageCN" "TouchToSearch_None_CTS" "ChatPPCN" "CarLinkApp"
        "Firewall" "HongbaoAssistant" "ChinaUnionPay" "ChinaHiddenMenu"
        "ChnFileShareKitService" "YourPhone_China" "LinkToWindowsService_China" "GimbalTrackingKit"
        "FusedLocation_Baidu" "MinorMode" "SightCare" "EasymodeContactsWidget81"
        "SamsungYellowPage" "PushServiceCN" "BudsUniteManager" "SendHelpMessage" "SketchBook"
        "SecSoterService" "SoterSskdsService"
    )
    quantum_remove "system" "etc/permissions/privapp-permissions-com.baidu.location.fused.xml"
    quantum_remove "system" "lib/libBDoeminfo_baidusearch.so"
    quantum_remove "system" "lib/libBDoeminfo_baidu.so"
    quantum_remove "system" "etc/sysconfig/pushservicecn.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.settingshelper.xml"
    quantum_remove "system" "etc/sysconfig/settingshelper.xml"
    quantum_remove "system" "etc/default-permissions/default-permissions-com.samsung.android.visualars.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.visualars.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.wssyncmldm.xml"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.android.svcagent.xml"
    quantum_remove "system" "system/etc/proca.db"

    # Network Sim Lock
    BLOAT_TARGETS+=("SsuService")
    quantum_remove "system" "bin/ssud"
    quantum_remove "system" "etc/init/ssu.rc"
    quantum_remove "system" "etc/permissions/privapp-permissions-com.samsung.ssu.xml"
    quantum_remove "system" "etc/sysconfig/samsungsimunlock.xml"
    quantum_remove "system" "lib64/android.security.securekeygeneration-ndk.so"
    quantum_remove "system" "lib64/libssu_keystore2.so"

    # ── 5. Dynamic removal across all sub-partitions ──────────────────────────
    for app_name in "${BLOAT_TARGETS[@]}"; do
        find "${TARGET_DIR}" -type d -name "$app_name" -exec rm -rf {} + >/dev/null 2>&1
    done

    # ── 6. Wipe stock recovery overwrite scripts ──────────────────────────────
    quantum_remove "vendor" "recovery-from-boot.p"
    quantum_remove "vendor" "bin/install-recovery.sh"
    quantum_remove "vendor" "etc/init/vendor_flash_recovery.rc"
    quantum_remove "vendor" "etc/recovery-resource.dat"

    echo "  - Success: Atomic debloat processed seamlessly."
}
