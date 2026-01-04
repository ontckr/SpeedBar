#!/bin/bash

# SpeedBar DMG Build Script
# This script builds the SpeedBar app and packages it into a DMG file.
# 
# Usage: ./build_dmg.sh [release|debug]
# Default: release

set -e

# Configuration
APP_NAME="SpeedBar"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODE_PROJECT="${PROJECT_DIR}/SpeedBar.xcodeproj"
BUILD_CONFIG="${1:-Release}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate build configuration
if [[ "${BUILD_CONFIG}" != "Release" && "${BUILD_CONFIG}" != "Debug" ]]; then
    BUILD_CONFIG="Release"
    echo_warn "Invalid build configuration. Using Release."
fi

echo_info "Building ${APP_NAME} (${BUILD_CONFIG})..."

# Create build directory
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_DIR="${BUILD_DIR}/dmg"

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${EXPORT_PATH}"
mkdir -p "${DMG_DIR}"

# Build the app
echo_info "Building Xcode project..."
xcodebuild -project "${XCODE_PROJECT}" \
    -scheme "${APP_NAME}" \
    -configuration "${BUILD_CONFIG}" \
    -archivePath "${ARCHIVE_PATH}" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "(Compiling|Linking|Copying|Building|Archive|error:|warning:)" || true

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo_error "Build failed. Archive not created."
    exit 1
fi

echo_info "Exporting app..."

# Create export options plist
EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"
cat > "${EXPORT_OPTIONS}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
</dict>
</plist>
EOF

# Export the archive (or just copy from archive for unsigned builds)
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    # Try alternative location
    APP_PATH="${ARCHIVE_PATH}/Products/usr/local/bin/${APP_NAME}.app"
fi

if [ ! -d "${APP_PATH}" ]; then
    echo_warn "Could not find app in archive. Attempting direct build..."
    
    # Direct build as fallback
    xcodebuild -project "${XCODE_PROJECT}" \
        -scheme "${APP_NAME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | grep -E "(Compiling|Linking|Copying|Building|error:|warning:)" || true
    
    APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -1)
fi

if [ ! -d "${APP_PATH}" ]; then
    echo_error "Build failed. App not found."
    exit 1
fi

# Copy app to DMG staging directory
echo_info "Preparing DMG contents..."
cp -R "${APP_PATH}" "${DMG_DIR}/"

# Add Applications shortcut
ln -s /Applications "${DMG_DIR}/Applications"

# Get version from Info.plist
VERSION=$(defaults read "${DMG_DIR}/${APP_NAME}.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD_NUMBER=$(defaults read "${DMG_DIR}/${APP_NAME}.app/Contents/Info" CFBundleVersion 2>/dev/null || echo "1")

DMG_NAME="${APP_NAME}-${VERSION}-${BUILD_NUMBER}.dmg"
DMG_PATH="${PROJECT_DIR}/${DMG_NAME}"

# Remove existing DMG if present
rm -f "${DMG_PATH}"

# Create DMG
echo_info "Creating DMG: ${DMG_NAME}..."

# Calculate size needed (app size + 10MB buffer)
APP_SIZE=$(du -sm "${DMG_DIR}" | cut -f1)
DMG_SIZE=$((APP_SIZE + 10))

# Create temporary DMG
TEMP_DMG="${BUILD_DIR}/temp.dmg"
hdiutil create -srcfolder "${DMG_DIR}" \
    -volname "${APP_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "${TEMP_DMG}"

# Mount temporary DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "${TEMP_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $NF}')

if [ -n "${MOUNT_DIR}" ]; then
    # Set background and icon positions (optional customization)
    # You can customize the DMG appearance here using AppleScript or DS_Store
    
    # Unmount
    hdiutil detach "${MOUNT_DIR}" -quiet
fi

# Convert to compressed DMG
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}"

# Clean up
rm -f "${TEMP_DMG}"

echo_info "DMG created successfully!"
echo ""
echo "================================================"
echo -e "${GREEN}Build Complete!${NC}"
echo "================================================"
echo ""
echo "Output: ${DMG_PATH}"
echo "Size: $(du -h "${DMG_PATH}" | cut -f1)"
echo ""
echo -e "${YELLOW}Note: This DMG is not signed or notarized.${NC}"
echo "You will need to sign and notarize before distribution."
echo ""

# Optionally open the DMG
if [ "$2" == "--open" ]; then
    open "${DMG_PATH}"
fi

