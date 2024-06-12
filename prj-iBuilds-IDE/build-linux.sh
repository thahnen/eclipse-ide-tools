#!/usr/bin/env bash

# Eclipse installation from latest stable integration build
# =========================================================

DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BUILD_DIR="$DIR/build"
COMPOSITE_ARTIFACTS_JAR_FILE="$BUILD_DIR/compositeArtifacts.jar"
COMPOSITE_ARTIFACTS_XML_FILE="$BUILD_DIR/compositeArtifacts.xml"
ARCHIVE_FILE="$BUILD_DIR/archive.tar.gz"

# Replace template with value in a file
function replaceStringInFile() {
    sed -ir "s#$2#$3#" $1
    rm "$1r"
}

# Await user input until "yes" is answered
function awaitUser() {
    while true; do
        read -p "$1 " yn
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
ECLIPSE_TARGZ_TEMPLATE="https://www.eclipse.org/downloads/download.php?file=/eclipse/downloads/drops4/VERSION/eclipse-SDK-VERSION-linux-gtk-ARCH.tar.gz"

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
#   2) Download archive and prepare the actual installation for changes
# =============================================================================
ECLIPSE_URL="${ECLIPSE_TARGZ_TEMPLATE//VERSION/$I_BUILDS_VERSION}"
ECLIPSE_URL="${ECLIPSE_URL//ARCH/$ECLIPSE_ARCH}"
APPLICATION_DIR="$BUILD_DIR/Eclipse-$I_BUILDS_VERSION"
APPLICATION_NAME="$(basename $APPLICATION_DIR)"

wget $ECLIPSE_URL -O $ARCHIVE_FILE
mkdir $APPLICATION_DIR
tar -xzf $ARCHIVE_FILE -C $BUILD_DIR
mv $BUILD_DIR/eclipse/* $APPLICATION_DIR
rm -rf $BUILD_DIR/eclipse
rm -f $ARCHIVE_FILE


# =============================================================================
#   3) Fix configuration: config.ini with default workspace
# =============================================================================
CONFIG_DIR="$APPLICATION_DIR/configuration"

replaceStringInFile "$CONFIG_DIR/config.ini" "@user.home/workspace" \
    "@user.home/workspaces/$I_BUILDS_VERSION"


# =============================================================================
#   4) Install necessary plug-ins for development
# =============================================================================
$APPLICATION_DIR/eclipse -noSplash \
    -application org.eclipse.equinox.p2.director \
    -repository https://download.eclipse.org/technology/m2e/snapshots/latest/ \
    -installIU org.eclipse.m2e.sdk.feature.feature.group \
    -profile SDKProfile \
    -followReferences

if [[ -z ${SKIP_SONARLINT+x} ]]; then
    $APPLICATION_DIR/eclipse -noSplash \
        -application org.eclipse.equinox.p2.director \
        -repository https://binaries.sonarsource.com/SonarLint-for-Eclipse/dogfood/ \
        -installIU org.sonarlint.eclipse.feature.feature.group \
        -profile SDKProfile \
        -followReferences
fi

$APPLICATION_DIR/eclipse -noSplash \
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

$APPLICATION_DIR/eclipse -noSplash \
    -application org.eclipse.equinox.p2.director \
    -repository https://download.eclipse.org/windowbuilder/updates/milestone/latest/ \
    -installIU org.eclipse.wb.core.feature.feature.group,\
org.eclipse.wb.doc.user.feature.feature.group,\
org.eclipse.wb.core.ui.feature.feature.group,\
org.eclipse.wb.layout.group.feature.feature.group,\
org.eclipse.wb.core.java.feature.feature.group,\
org.eclipse.wb.swing.feature.feature.group,\
org.eclipse.wb.swing.doc.user.feature.feature.group,\
org.eclipse.wb.rcp.feature.feature.group,\
org.eclipse.wb.swt.feature.feature.group,\
org.eclipse.wb.rcp.doc.user.feature.feature.group,\
org.eclipse.wb.rcp.SWT_AWT_support.feature.group \
    -profile SDKProfile \
    -followReferences


# =============================================================================
#   5) Remove logs
# =============================================================================
pushd $CONFIG_DIR
rm *.log
popd


# =============================================================================
#   6) Remove all the old workspaces
# =============================================================================
if ls $HOME/workspaces/I* >/dev/null 2>&1; then
    for workspace in $HOME/workspaces/I*; do
        rm -rf $workspace
    done
fi


# =============================================================================
#   7) Move to user application folder and delete old ones
# =============================================================================
APPLICATIONS_DIR="$HOME/applications"
if [[ ! -d "$APPLICATIONS_DIR" ]]; then
    mkdir -p $APPLICATIONS_DIR/$APPLICATION_NAME
fi

if ls $APPLICATIONS_DIR/Eclipse-I* >/dev/null 2>&1; then
    for ibuilds_installation in $APPLICATIONS_DIR/Eclipse-I*; do
        INSTALLATION_NAME="$(basename $ibuilds_installation)"
        rm -rf $ibuilds_installation
    done
fi

cp -r $APPLICATION_DIR $APPLICATIONS_DIR/$APPLICATION_NAME


# =============================================================================
#   8) Create desktop files and delete old ones
# =============================================================================
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/$APPLICATION_NAME.desktop"

if [[ ! -d "$DESKTOP_DIR" ]]; then
    mkdir -p $DESKTOP_DIR
fi

for ibuilds_installation in $DESKTOP_DIR/Eclipse-I*; do
    rm -f $ibuilds_installation
done

cp $DIR/Eclipse-iBuilds.desktop $DESKTOP_FILE

replaceStringInFile $DESKTOP_FILE "TPL_APPLICATION_NAME" "$APPLICATION_NAME"
replaceStringInFile $DESKTOP_FILE "TPL_HOME_DIR" "$HOME"
xdg-desktop-menu forceupdate
