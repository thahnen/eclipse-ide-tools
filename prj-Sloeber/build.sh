#!/usr/bin/env bash

# Sloeber (Arduino IDE) installation based on the last version
# ============================================================

DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BUILD_DIR="$DIR/build"
ZIP_FILE="$BUILD_DIR/sloeber.zip"
INSTALLATION_DIR="$BUILD_DIR/Sloeber.app"

# Replace template with value in a file
function replaceStringInFile() {
    sed -ir "s#$2#$3#" $1
    rm "$1r"
}


# =============================================================================
#   *) Templated and fallback configuration
# =============================================================================
SLOEBER_VERSION="4.4.3"
SLOEBER_TAG="V4_4_3_0"
SLOBER_ZIP_TEMPLATE="https://github.com/Sloeber/arduino-eclipse-plugin/releases/download/TAG/sloeber-ide-VVERSION-macosx.cocoa.ARCH.zip"

SLOEBER_ARCH="$(uname -m)"
if [[ "$SLOEBER_ARCH" == "arm64" ]]; then
    SLOEBER_ARCH="aarch64"
fi


# =============================================================================
#   1) Remove old artifacts
# =============================================================================
rm -rf $BUILD_DIR


# =============================================================================
#   2) Check for all necessary dependencies
# =============================================================================
which wget
if [[ "$?" -ne "0" ]]; then
    echo "'wget' required, please run 'brew install wget'!"
    return
fi


# =============================================================================
#   3) Download and unzip ZIP archive
# =============================================================================

mkdir $BUILD_DIR

SLOEBER_URL="${SLOBER_ZIP_TEMPLATE//VERSION/$SLOEBER_VERSION}"
SLOEBER_URL="${SLOEBER_URL//TAG/$SLOEBER_TAG}"
SLOEBER_URL="${SLOEBER_URL//ARCH/$SLOEBER_ARCH}"

wget $SLOEBER_URL -O $ZIP_FILE --no-check-certificate
unzip $ZIP_FILE -d $BUILD_DIR
rm -f $ZIP_FILE


# =============================================================================
#   4) Adjust installation with necessary files not yet present
# =============================================================================

rm -rf "$INSTALLATION_DIR/Contents/Eclipse.app"
cp "$DIR/Info.plist" "$INSTALLATION_DIR/Contents"
mkdir "$INSTALLATION_DIR/Contents/Resources"
cp "$DIR/Sloeber.icns" "$INSTALLATION_DIR/Contents/Resources"


# =============================================================================
#   5) Fix INI file required for binary launcher
# =============================================================================

INI_FILE="$INSTALLATION_DIR/Contents/Eclipse/sloeber-ide.ini"

replaceStringInFile $INI_FILE "-perspective" ""
replaceStringInFile $INI_FILE "io.sloeber.product.perspective" ""


# =============================================================================
#   6) Fix Arduino board manager JSON file
# =============================================================================

SETTINGS_DIR="$INSTALLATION_DIR/Contents/Eclipse/configuration/.settings"
PREFS_FILE="$SETTINGS_DIR/io.sloeber.arduino.prefs"

mkdir "$SETTINGS_DIR"
cp "$DIR/io.sloeber.arduino.prefs" "$SETTINGS_DIR"

replaceStringInFile $PREFS_FILE "LOCAL_FILE" \
    "$DIR/library_index.json"


# =============================================================================
#   7) Sign again, don't remove logs in case something didn't work correctly
# =============================================================================
touch "$INSTALLATION_DIR"
codesign --force --deep --sign - "$INSTALLATION_DIR"
xattr -d com.apple.quarantine "$INSTALLATION_DIR"
touch "$INSTALLATION_DIR"
codesign --force --deep --sign - "$INSTALLATION_DIR"


# =============================================================================
#   8) Move to user application folder and delete old ones
# =============================================================================

APPLICATIONS_DIR="$HOME/Applications"
if [[ ! -d "$APPLICATIONS_DIR" ]]; then
    mkdir -p "$APPLICATIONS_DIR/Sloeber.app"
fi

mv $INSTALLATION_DIR "$APPLICATIONS_DIR/Sloeber.app"
