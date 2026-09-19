#!/bin/bash
# =============================================================================
#  QuantumROM — smali_patch.sh
#  SMALI_PATCH reimplementation based on UN1CA ROM smali_utils.sh
#  Adapted to use QuantumROM's DECOMPILE/RECOMPILE/HEX_PATCH conventions (now you cant say this is a kang, majah!)
# =============================================================================

# SMALI_PATCH <partition> <apk/jar> <smali> <operation> [method] [value] [replacement]
#
# Operations:
#   null <method>                          → nullify void method body
#   remove                                 → delete the smali file entirely
#   replace <method> <value> <replacement> → replace string inside method
#   replaceall <value> <replacement>       → replace all occurrences in file
#   return <method> <value>                → force method to return a value
#   strip <method>                         → delete method declaration entirely
SMALI_PATCH() {
    if [ "$#" -lt 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <PARTITION> <FILE> <SMALI> <OPERATION> [METHOD] [VALUE] [REPLACEMENT]"
        return 1
    fi

    local PARTITION="$1"
    local FILE="$2"
    local SMALI="$3"
    local OPERATION="$4"

    # Strip leading slashes from FILE
    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    # Resolve partition root
    local PART_DIR
    case "$PARTITION" in
        system)      PART_DIR="$FIRM_DIR/$TARGET_DEVICE/system/system" ;;
        product)     PART_DIR="$FIRM_DIR/$TARGET_DEVICE/product" ;;
        system_ext)  PART_DIR="$FIRM_DIR/$TARGET_DEVICE/system_ext" ;;
        vendor)      PART_DIR="$FIRM_DIR/$TARGET_DEVICE/vendor" ;;
        *)
            echo -e "[SMALI_PATCH] Unknown partition: $PARTITION"
            return 1
            ;;
    esac

    local FULL_FILE="$PART_DIR/$FILE"
    local BASENAME
    BASENAME="$(basename "${FILE%.*}")"
    local DECOMPILED_DIR="$WORK_DIR/$BASENAME"

    # Validate operation
    case "$OPERATION" in
        null|remove|replace|replaceall|return|strip) ;;
        *)
            echo -e "[SMALI_PATCH] Invalid operation: $OPERATION"
            return 1
            ;;
    esac

    # Parse extra args
    local METHOD VALUE REPLACEMENT
    if [[ "$OPERATION" == "replaceall" ]]; then
        VALUE="$5"
        REPLACEMENT="$6"
    elif [[ "$OPERATION" != "remove" ]]; then
        METHOD="$5"
    fi
    [[ "$OPERATION" == "return" ]]  && VALUE="$6"
    [[ "$OPERATION" == "replace" ]] && VALUE="$6" && REPLACEMENT="$7"

    # Decompile if not already done
    if [ ! -d "$DECOMPILED_DIR" ]; then
        DECOMPILE "$APKTOOL" \
            "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" \
            "$FULL_FILE" \
            "$WORK_DIR" || return 1
    fi

    local FILE_PATH="$DECOMPILED_DIR/$SMALI"

    # Check smali exists
    if [ ! -f "$FILE_PATH" ]; then
        echo -e "[SMALI_PATCH] Smali not found: $FILE_PATH"
        find "$DECOMPILED_DIR" -type f -name "*${SMALI##*/}" | head -10
        return 1
    fi

    # ── remove ────────────────────────────────────────────────────────────────
    if [[ "$OPERATION" == "remove" ]]; then
        local USED
        USED="$(find "$DECOMPILED_DIR" ! -path "*$SMALI" -type f \
            -exec grep -rn -- "$(cut -d "." -f "1" <<< "${SMALI#*/}");" {} \+ || true)"
        if [ "$USED" ]; then
            echo -e "[SMALI_PATCH] Cannot remove $SMALI — used elsewhere:"
            echo "$USED" | head -10
            return 1
        fi
        echo -e "[SMALI_PATCH] Removing: $SMALI"
        rm -f "$FILE_PATH"
        return 0
    fi

    # Check method exists
    if ! grep "^\.method.*" "$FILE_PATH" | grep -qF -- "$METHOD"; then
        case "$OPERATION" in
            strip)
                echo -e "[SMALI_PATCH] Already stripped: $METHOD"
                return 0
                ;;
        esac

        echo -e "[SMALI_PATCH] Method not found: $METHOD in $SMALI"
        grep -r "^\.method.*$METHOD" "$DECOMPILED_DIR" | head -10
        return 1
    fi

    local BEFORE AFTER
    BEFORE="$(sha1sum "$FILE_PATH")"

    # ── strip ─────────────────────────────────────────────────────────────────
    if [[ "$OPERATION" == "strip" ]]; then
        local USED
        USED="$(grep -rn -- "invoke.*$(basename "$SMALI" | cut -d "." -f "1");" "$DECOMPILED_DIR" \
            | grep -F "$METHOD" | cut -d ":" -f 1-2 || true)"
        if [ "$USED" ]; then
            echo -e "[SMALI_PATCH] Cannot strip $METHOD — used elsewhere"
            echo "$USED" | head -10
            return 1
        fi
        echo -e "[SMALI_PATCH] Stripping method: $METHOD"
        awk -v FN="$METHOD" '
            BEGIN { inside=0; skip=0 }
            /^\.method/ && index($0,FN) { inside=1; next }
            inside && /^\.end method/ { inside=0; skip=1; next }
            inside { next }
            { if(skip){ skip=0; next }; print }
        ' "$FILE_PATH" > "$FILE_PATH.tmp" && mv "$FILE_PATH.tmp" "$FILE_PATH"

    # ── null ──────────────────────────────────────────────────────────────────
    elif [[ "$OPERATION" == "null" ]]; then
        local RET="${METHOD#*)}"
        if [[ "$RET" != "V" ]]; then
            echo -e "[SMALI_PATCH] Cannot nullify non-void method: $METHOD"
            return 1
        fi
        echo -e "[SMALI_PATCH] Nullifying method: $METHOD"
        awk -v FN="$METHOD" '
            BEGIN { inside=0 }
            /^\.method/ && index($0,FN) {
                print; print "    .locals 0"; print ""; print "    return-void"
                inside=1; next
            }
            inside && /^\.end method/ { print; inside=0; next }
            inside { next }
            { print }
        ' "$FILE_PATH" > "$FILE_PATH.tmp" && mv "$FILE_PATH.tmp" "$FILE_PATH"

    # ── return ────────────────────────────────────────────────────────────────
    elif [[ "$OPERATION" == "return" ]]; then
        local RET="${METHOD#*)}"
        local REG="p0"
        local LOC=".locals 0"
        local RET_INST

        if grep "^\.method.*" "$FILE_PATH" | grep -F -- "$METHOD" | grep -q " static " \
                && [[ "$METHOD" == *"()"* ]]; then
            REG="v0"; LOC=".locals 1"
        fi

        if [[ "$RET" == "V" ]]; then
            echo -e "[SMALI_PATCH] Cannot change return of void method: $METHOD"
            return 1
        elif [[ "$RET" == "Ljava/lang/String;" ]]; then
            VALUE="\"$VALUE\""
            RET_INST="return-object $REG"
        elif [[ "$RET" =~ ^\[*[ZBCSIJFD]$ ]]; then
            [[ "$VALUE" == "true" ]]  && VALUE="0x1"
            [[ "$VALUE" == "false" ]] && VALUE="0x0"
            [[ "$VALUE" =~ ^-?[0-9]+$ ]] && VALUE="0x$(printf "%x" "$VALUE")"
            [[ "$RET" == "J" ]] && RET_INST="return-wide $REG" || RET_INST="return $REG"
        else
            [[ "$VALUE" == "null" ]] && VALUE="0x0"
            RET_INST="return-object $REG"
        fi

        # const instruction
        local CONST_INST
        if [[ "$VALUE" =~ ^\".*\"$ ]]; then
            CONST_INST="const-string $REG, $VALUE"
        else
            local hex num
            [[ "$VALUE" == "-"* ]] && hex="${VALUE#-0x}" && num="$((-16#$hex))" \
                                   || hex="${VALUE#0x}"  && num="$((16#$hex))"
            if [[ "$RET_INST" == "return-wide"* ]]; then
                CONST_INST="const-wide/16 $REG, $VALUE"
            elif [ "$num" -gt "-8" ] && [ "$num" -lt "8" ]; then
                CONST_INST="const/4 $REG, $VALUE"
            else
                CONST_INST="const/16 $REG, $VALUE"
            fi
        fi

        echo -e "[SMALI_PATCH] Forcing return of $METHOD → $CONST_INST"
        awk -v FN="$METHOD" -v LOC="$LOC" -v VAL="$CONST_INST" -v RET="$RET_INST" '
            BEGIN { inside=0 }
            /^\.method/ && index($0,FN) {
                print; print "    "LOC; print ""; print "    "VAL; print ""; print "    "RET
                inside=1; next
            }
            inside && /^\.end method/ { print; inside=0; next }
            inside { next }
            { print }
        ' "$FILE_PATH" > "$FILE_PATH.tmp" && mv "$FILE_PATH.tmp" "$FILE_PATH"

    # ── replace ───────────────────────────────────────────────────────────────
    elif [[ "$OPERATION" == "replace" ]]; then
        echo -e "[SMALI_PATCH] Replacing \"$VALUE\" → \"$REPLACEMENT\" in $METHOD"
        awk -v FN="$METHOD" -v STR="$VALUE" -v REP="$REPLACEMENT" '
            BEGIN { inside=0; isline=(index(REP,"\n")>0) }
            /^\.method/ && index($0,FN) { inside=1 }
            inside {
                if (isline) {
                    if (index($0,STR)) { gsub(/\\n/,"\n",REP); print REP; next }
                } else if ($0~/^[[:space:]]*const-string(\/jumbo)?/) {
                    sub("\""STR"\"","\""REP"\"")
                } else {
                    line=$0; gsub(/^[ \t]+|[ \t]+$/,"",line)
                    if (line==STR) { match($0,/^[ \t]+/); $0=substr($0,RSTART,RLENGTH)REP }
                }
            }
            inside && /^\.end method/ { inside=0 }
            { print }
        ' "$FILE_PATH" > "$FILE_PATH.tmp" && mv "$FILE_PATH.tmp" "$FILE_PATH"

    # ── replaceall ────────────────────────────────────────────────────────────
    elif [[ "$OPERATION" == "replaceall" ]]; then
        echo -e "[SMALI_PATCH] Replacing all \"$VALUE\" → \"$REPLACEMENT\" in $SMALI"
        sed -i "s|$VALUE|$REPLACEMENT|g" "$FILE_PATH"
    fi

    AFTER="$(sha1sum "$FILE_PATH")"
    if [[ "$BEFORE" == "$AFTER" ]]; then
        case "$OPERATION" in
            replace|replaceall|null|return)
                echo -e "[SMALI_PATCH] Already patched: $SMALI"
                return 0
                ;;
            *)
                echo -e "[SMALI_PATCH] WARNING: file unchanged after operation $OPERATION on $SMALI"
                return 1
                ;;
        esac
    fi

    echo -e "[SMALI_PATCH] Done: $OPERATION on $SMALI"
    return 0
}    