#!/bin/bash

#===============================================================================
# SpeedBar DMG Creator
#===============================================================================
# Creates a distributable DMG installer for SpeedBar using native macOS tools.
# Automatically signs and notarizes the app and DMG if credentials are configured.
#
# Usage:
#   ./create_dmg.sh [path-to-SpeedBar.app]
#
# Configuration file:
#   Create .dmg_config in project root with:
#     DEVELOPER_ID_NAME="Developer ID Application: Your Name (TEAM_ID)"
#     APPLE_ID="your@email.com"
#     APPLE_TEAM_ID="TEAM_ID"
#     NOTARIZATION_PASSWORD="@keychain:AC_PASSWORD"
#
# Output:
#   SpeedBar-{version}.dmg in the project root directory
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DMG_NAME="SpeedBar"
VOLUME_NAME="SpeedBar"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}"

STAGING_DIR="${SCRIPT_DIR}/.dmg_staging"
DMG_TEMP="${STAGING_DIR}/${DMG_NAME}_temp.dmg"

CONFIG_FILE="${SCRIPT_DIR}/.dmg_config"
if [ -f "${CONFIG_FILE}" ]; then
    source "${CONFIG_FILE}"
fi

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

print_info() {
    echo -e "${BLUE}Info:${NC} $1"
}

cleanup() {
    print_step "Cleaning up temporary files..."
    
    if mount | grep -q "/Volumes/${VOLUME_NAME}"; then
        hdiutil detach "/Volumes/${VOLUME_NAME}" -quiet 2>/dev/null || true
    fi
    
    if [ -d "${STAGING_DIR}" ]; then
        rm -rf "${STAGING_DIR}"
    fi
}

trap cleanup EXIT

find_app() {
    local app_path="$1"
    
    if [ -n "$app_path" ] && [ -d "$app_path" ]; then
        echo "$app_path"
        return 0
    fi
    
    local derived_data_paths=(
        "${SCRIPT_DIR}/build/DerivedData"
        "${HOME}/Library/Developer/Xcode/DerivedData"
    )
    
    for dd_path in "${derived_data_paths[@]}"; do
        if [ -d "$dd_path" ]; then
            local found=$(find "$dd_path" -maxdepth 5 -path "*/Build/Products/Release/SpeedBar.app" -type d 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                echo "$found"
                return 0
            fi
            found=$(find "$dd_path" -maxdepth 5 -path "*/Build/Products/Debug/SpeedBar.app" -type d 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                echo "$found"
                return 0
            fi
        fi
    done
    
    return 1
}

get_app_version() {
    local app_path="$1"
    local version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${app_path}/Contents/Info.plist" 2>/dev/null || echo "1.0")
    echo "$version"
}

sign_app() {
    local app_path="$1"
    local sign_identity="$2"
    
    if [ -z "$sign_identity" ]; then
        print_error "No signing identity provided"
        return 1
    fi
    
    print_step "Signing SpeedBar.app with ${sign_identity}..."
    
    codesign --remove-signature "${app_path}" 2>/dev/null || true
    
    if codesign --force --deep --options runtime \
        --sign "${sign_identity}" \
        --timestamp \
        "${app_path}"; then
        print_step "App signed successfully"
        
        if codesign -vv --deep --strict "${app_path}" 2>&1; then
            print_step "Signature verified"
            return 0
        else
            print_warning "Signature verification had warnings"
            return 0
        fi
    else
        print_error "Failed to sign app"
        return 1
    fi
}

sign_dmg() {
    local dmg_path="$1"
    local sign_identity="$2"
    
    if [ -z "$sign_identity" ]; then
        print_error "No signing identity provided"
        return 1
    fi
    
    print_step "Signing DMG with ${sign_identity}..."
    
    if codesign --force --sign "${sign_identity}" \
        --timestamp \
        "${dmg_path}"; then
        print_step "DMG signed successfully"
        return 0
    else
        print_error "Failed to sign DMG"
        return 1
    fi
}

notarize_dmg() {
    local dmg_path="$1"
    local apple_id="$2"
    local team_id="$3"
    local password="$4"
    
    if [ -z "$apple_id" ] || [ -z "$team_id" ] || [ -z "$password" ]; then
        print_warning "Notarization skipped: missing credentials"
        return 1
    fi
    
    print_step "Submitting DMG for notarization..."
    print_info "This may take a few minutes..."
    
    local submission_output
    submission_output=$(xcrun notarytool submit "${dmg_path}" \
        --apple-id "${apple_id}" \
        --team-id "${team_id}" \
        --password "${password}" \
        --wait 2>&1)
    
    echo "$submission_output"
    
    if echo "$submission_output" | grep -q "status: Accepted"; then
        print_step "Notarization accepted!"
        
        print_step "Stapling notarization ticket..."
        if xcrun stapler staple "${dmg_path}"; then
            print_step "Notarization ticket stapled successfully"
            return 0
        else
            print_warning "Failed to staple ticket"
            return 1
        fi
    else
        print_error "Notarization failed"
        return 1
    fi
}

find_signing_identity() {
    local identity
    identity=$(security find-identity -v -p codesigning 2>/dev/null | \
        grep "Developer ID Application" | \
        head -1 | \
        sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -n "$identity" ]; then
        echo "$identity"
        return 0
    fi
    
    return 1
}

APP_PATH_ARG="$1"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               SpeedBar DMG Installer Creator                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

print_step "Locating SpeedBar.app..."

APP_PATH=$(find_app "$APP_PATH_ARG" || echo "")

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    print_error "Could not find SpeedBar.app"
    echo ""
    echo "Please build the app in Release mode first:"
    echo ""
    echo "  Option 1 - Using Xcode:"
    echo "    1. Open SpeedBar.xcodeproj"
    echo "    2. Select Product > Archive"
    echo "    3. Or press ⇧⌘B for Release build"
    echo ""
    echo "  Option 2 - Using command line:"
    echo "    xcodebuild -project SpeedBar.xcodeproj -scheme SpeedBar -configuration Release build"
    echo ""
    echo "Then run this script again, or provide the path:"
    echo "    ./create_dmg.sh /path/to/SpeedBar.app"
    echo ""
    exit 1
fi

echo "   Found: ${APP_PATH}"

if [ ! -f "${APP_PATH}/Contents/Info.plist" ]; then
    print_error "Invalid app bundle: missing Info.plist"
    exit 1
fi

APP_VERSION=$(get_app_version "${APP_PATH}")
DMG_FILENAME="${DMG_NAME}-${APP_VERSION}.dmg"

print_info "App version: ${APP_VERSION}"

print_step "Creating staging directory..."
cleanup
mkdir -p "${STAGING_DIR}/dmg_contents"

print_step "Copying SpeedBar.app to staging area..."
cp -R "${APP_PATH}" "${STAGING_DIR}/dmg_contents/"
APP_COPY="${STAGING_DIR}/dmg_contents/SpeedBar.app"

SIGNING_IDENTITY=""
if [ -n "$DEVELOPER_ID_NAME" ]; then
    SIGNING_IDENTITY="$DEVELOPER_ID_NAME"
else
    SIGNING_IDENTITY=$(find_signing_identity || echo "")
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    print_info "Using signing identity: ${SIGNING_IDENTITY}"
    
    if sign_app "${APP_COPY}" "${SIGNING_IDENTITY}"; then
        echo "   App signed successfully"
    else
        print_error "App signing failed"
        exit 1
    fi
else
    print_error "No Developer ID Application certificate found"
    echo ""
    echo "Please ensure you have a Developer ID Application certificate:"
    echo "  1. Open Xcode → Settings → Accounts"
    echo "  2. Select your team → Manage Certificates"
    echo "  3. Click + → Developer ID Application"
    echo ""
    exit 1
fi

print_step "Creating Applications shortcut..."
ln -s /Applications "${STAGING_DIR}/dmg_contents/Applications"

print_step "Calculating DMG size..."
APP_SIZE=$(du -sm "${STAGING_DIR}/dmg_contents" | cut -f1)
DMG_SIZE=$((APP_SIZE + APP_SIZE / 5 + 10))
echo "   App size: ${APP_SIZE}MB, DMG size: ${DMG_SIZE}MB"

print_step "Creating temporary DMG..."
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}/dmg_contents" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE}m" \
    "${DMG_TEMP}" \
    -quiet

print_step "Configuring DMG appearance..."
hdiutil attach "${DMG_TEMP}" -readwrite -noverify -quiet

osascript << EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        
        set bounds of container window to {100, 100, 640, 400}
        
        set opts to icon view options of container window
        set icon size of opts to 80
        set arrangement of opts to not arranged
        
        set position of item "SpeedBar.app" of container window to {140, 150}
        set position of item "Applications" of container window to {400, 150}
        
        close
        open
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync

print_step "Finalizing DMG layout..."
hdiutil detach "/Volumes/${VOLUME_NAME}" -quiet

print_step "Converting to read-only compressed DMG..."

if [ -f "${OUTPUT_DIR}/${DMG_FILENAME}" ]; then
    print_warning "Removing existing ${DMG_FILENAME}"
    rm -f "${OUTPUT_DIR}/${DMG_FILENAME}"
fi

hdiutil convert \
    "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${OUTPUT_DIR}/${DMG_FILENAME}" \
    -quiet

if [ -n "$SIGNING_IDENTITY" ]; then
    if ! sign_dmg "${OUTPUT_DIR}/${DMG_FILENAME}" "${SIGNING_IDENTITY}"; then
        print_error "DMG signing failed"
        exit 1
    fi
fi

if [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$NOTARIZATION_PASSWORD" ]; then
    if notarize_dmg "${OUTPUT_DIR}/${DMG_FILENAME}" "${APPLE_ID}" "${APPLE_TEAM_ID}" "${NOTARIZATION_PASSWORD}"; then
        print_step "DMG is signed and notarized - ready for distribution!"
    else
        print_error "Notarization failed"
        echo ""
        echo "Please check your credentials in .dmg_config:"
        echo "  APPLE_ID=\"your@email.com\""
        echo "  APPLE_TEAM_ID=\"TEAM_ID\""
        echo "  NOTARIZATION_PASSWORD=\"@keychain:AC_PASSWORD\""
        echo ""
        exit 1
    fi
else
    print_error "Notarization credentials not configured"
    echo ""
    echo "Please create .dmg_config file with:"
    echo "  DEVELOPER_ID_NAME=\"Developer ID Application: Your Name (TEAM_ID)\""
    echo "  APPLE_ID=\"your@email.com\""
    echo "  APPLE_TEAM_ID=\"TEAM_ID\""
    echo "  NOTARIZATION_PASSWORD=\"@keychain:AC_PASSWORD\""
    echo ""
    echo "To store password in keychain:"
    echo "  xcrun notarytool store-credentials AC_PASSWORD --apple-id YOUR_EMAIL --team-id TEAM_ID"
    echo ""
    exit 1
fi

print_step "Verifying DMG integrity..."
hdiutil verify "${OUTPUT_DIR}/${DMG_FILENAME}" -quiet

FINAL_SIZE=$(du -h "${OUTPUT_DIR}/${DMG_FILENAME}" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    DMG Created Successfully!                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "   Output: ${OUTPUT_DIR}/${DMG_FILENAME}"
echo "   Size:   ${FINAL_SIZE}"
echo "   Version: ${APP_VERSION}"
echo ""

if codesign -dv "${OUTPUT_DIR}/${DMG_FILENAME}" 2>&1 | grep -q "code object is not signed"; then
    echo "   Signing: ❌ Not signed"
else
    echo "   Signing: ✅ Signed"
fi

if xcrun stapler validate "${OUTPUT_DIR}/${DMG_FILENAME}" 2>/dev/null | grep -q "The validate action worked"; then
    echo "   Notarization: ✅ Notarized"
else
    echo "   Notarization: ❌ Not notarized"
fi

echo ""
echo "To test the DMG:"
echo "   open ${OUTPUT_DIR}/${DMG_FILENAME}"
echo ""
echo "✅ DMG is ready for distribution!"
echo ""

