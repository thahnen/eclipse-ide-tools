#!/usr/bin/env bash

# Eclipse installation from latest stable integration build
# =========================================================

DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BUILD_DIR="$DIR/build"
COMPOSITE_ARTIFACTS_JAR_FILE="$BUILD_DIR/compositeArtifacts.jar"
COMPOSITE_ARTIFACTS_XML_FILE="$BUILD_DIR/compositeArtifacts.xml"
INSTALLER_FILE="$BUILD_DIR/installer.dmg"

# Replace template with value in a file
function replaceStringInFile() {
    sed -ir "s#$2#$3#" $1
    rm "$1r"
}

# Await user input until "yes" is answered 
function awaitUser() {
    while true; do
        read "yn?$1 "
        case $yn in
            [Yy]* ) break;;
            *) echo "Please answer with yes!";;
        esac
    done
}


# =============================================================================
#   *) Templated and fallback configuration
# =============================================================================
ECLIPSE_VERSION="4.32"
ECLIPSE_COMPOSITE_URL="https://www.eclipse.org/downloads/download.php?file=/eclipse/updates/$ECLIPSE_VERSION-I-builds/compositeArtifacts.jar"
ECLIPSE_DMG_TEMPLATE="https://www.eclipse.org/downloads/download.php?file=/eclipse/downloads/drops4/VERSION/eclipse-SDK-VERSION-macosx-cocoa-ARCH.dmg"

ECLIPSE_ARCH="$(uname -m)"
if [[ "$ECLIPSE_ARCH" == "arm64" ]]; then
    ECLIPSE_ARCH="aarch64"
fi


# =============================================================================
#   1) Remove old artifacts
# =============================================================================
rm -rf $BUILD_DIR


# =============================================================================
#   2) Download compositeArtifacts.jar and extract XML for newest version
# =============================================================================
mkdir $BUILD_DIR
wget $ECLIPSE_COMPOSITE_URL -O $COMPOSITE_ARTIFACTS_JAR_FILE
unzip $COMPOSITE_ARTIFACTS_JAR_FILE -d $BUILD_DIR
rm -f $COMPOSITE_ARTIFACTS_JAR_FILE

I_BUILDS_VERSION="$(xmllint --xpath 'string(/repository/children/child[last()]/@location)' $COMPOSITE_ARTIFACTS_XML_FILE)"


# =============================================================================
#   2) Download installer and unzip the actual installation
# =============================================================================
ECLIPSE_URL="${ECLIPSE_DMG_TEMPLATE//VERSION/$I_BUILDS_VERSION}"
ECLIPSE_URL="${ECLIPSE_URL//ARCH/$ECLIPSE_ARCH}"

wget $ECLIPSE_URL -O $INSTALLER_FILE
7zz -o$BUILD_DIR x $INSTALLER_FILE
rm -f $INSTALLER_FILE


# =============================================================================
#   3) Prepare iBuilds installation for additional changes
# =============================================================================
APPLICATION_NAME="Eclipse-$I_BUILDS_VERSION.app"
APPLICATION_FILE="$BUILD_DIR/$APPLICATION_NAME"

mv $BUILD_DIR/Eclipse/Eclipse.app $APPLICATION_FILE
rm -rf $BUILD_DIR/Eclipse


# =============================================================================
#   4) Fix configuration: config.ini with default workspace
# =============================================================================
CONFIG_DIR="$APPLICATION_FILE/Contents/Eclipse/configuration"

replaceStringInFile "$CONFIG_DIR/config.ini" "@user.home/Documents/workspace" \
    "@user.home/workspaces/$I_BUILDS_VERSION"


# =============================================================================
#   5) Fix installation: Info.plist with identifier / (display) name
# =============================================================================
INFO_PLIST="$APPLICATION_FILE/Contents/Info.plist"

replaceStringInFile $INFO_PLIST "<string>org.eclipse.sdk.ide</string>" \
    "<string>org.eclipse.sdk.ide.$I_BUILDS_VERSION</string>"
replaceStringInFile $INFO_PLIST "<string>Eclipse</string>" \
    "<string>Eclipse $I_BUILDS_VERSION</string>"


# =============================================================================
#   6) Install necessary plug-ins for development
# =============================================================================
touch "$APPLICATION_FILE"
codesign --force --deep --sign - "$APPLICATION_FILE"

$APPLICATION_FILE/Contents/MacOS/eclipse -noSplash \
    -application org.eclipse.equinox.p2.director \
    -repository https://download.eclipse.org/technology/m2e/snapshots/latest/ \
    -installIU org.eclipse.m2e.sdk.feature.feature.group \
    -profile SDKProfile \
    -followReferences

if [[ -z ${SKIP_SONARLINT+x} ]]; then
    $APPLICATION_FILE/Contents/MacOS/eclipse -noSplash \
        -application org.eclipse.equinox.p2.director \
        -repository https://binaries.sonarsource.com/SonarLint-for-Eclipse/dogfood/ \
        -installIU org.sonarlint.eclipse.feature.feature.group \
        -profile SDKProfile \
        -followReferences
fi

$APPLICATION_FILE/Contents/MacOS/eclipse -noSplash \
    -application org.eclipse.equinox.p2.director \
    -repository https://download.eclipse.org/reddeer/releases/latest/ \
    -installIU org.eclipse.reddeer.eclipse.feature.feature.group,\
org.eclipse.reddeer.logparser.feature.feature.group,\
org.eclipse.reddeer.recorder.feature.feature.group,\
org.eclipse.reddeer.spy.feature.feature.group,\
org.eclipse.reddeer.swt.feature.feature.group,\
org.eclipse.reddeer.ui.feature.feature.group \
    -profile SDKProfile \
    -followReferences


# =============================================================================
#   7) Remove logs and sign again
# =============================================================================
pushd $CONFIG_DIR
rm *.log
popd

touch "$APPLICATION_FILE"
codesign --force --deep --sign - "$APPLICATION_FILE"


# =============================================================================
#   8) Remove all the old workspaces
# =============================================================================
if ls $HOME/workspaces/I* >/dev/null 2>&1; then
    for workspace in $HOME/workspaces/I*; do
        rm -rf $workspace
    done
fi


# =============================================================================
#   9) Move to user application folder and delete old ones
# =============================================================================
APPLICATIONS_DIR="$HOME/Applications"
if [[ ! -d "$APPLICATIONS_DIR" ]]; then
    mkdir -p $APPLICATIONS_DIR/$APPLICATION_NAME
fi

if ls $APPLICATIONS_DIR/Eclipse-I* >/dev/null 2>&1; then
    for ibuilds_installation in $APPLICATIONS_DIR/Eclipse-I*; do
        INSTALLATION_NAME="$(basename $ibuilds_installation)"
        FOUND_I_BUILDS_VERSION=${INSTALLATION_NAME#"Eclipse-"}
        FOUND_I_BUILDS_VERSION=${FOUND_I_BUILDS_VERSION%".app"}
        rm -rf $ibuilds_installation
        which dockutil >/dev/null 2>&1
        if [[ "$?" -eq "0" ]]; then
            dockutil --remove "org.eclipse.sdk.ide.$FOUND_I_BUILDS_VERSION"
        fi
    done
fi

INSTALLATION_DIR="$APPLICATIONS_DIR/$APPLICATION_NAME"
mv $APPLICATION_FILE $INSTALLATION_DIR
which dockutil >/dev/null 2>&1
if [[ "$?" -eq "0" ]]; then
    dockutil --add $INSTALLATION_DIR
fi
