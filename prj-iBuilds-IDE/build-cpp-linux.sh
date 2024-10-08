#!/usr/bin/env bash

# Eclipse CPP installation from latest milestone
# ==============================================

DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
BUILD_DIR="$DIR/build"
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
ECLIPSE_VERSION="2024-12"
ECLIPSE_MILESTONE="M1"
ECLIPSE_TARGZ_TEMPLATE="https://ftp.halifax.rwth-aachen.de/eclipse/technology/epp/downloads/release/VERSION/MILESTONE/eclipse-cpp-VERSION-MILESTONE-linux-gtk-ARCH.tar.gz"

ECLIPSE_ARCH="$(uname -m)"
if [[ "$ECLIPSE_ARCH" == "arm64" ]]; then
    ECLIPSE_ARCH="aarch64"
fi


# =============================================================================
#   1) Remove old artifacts
# =============================================================================
rm -rf $BUILD_DIR


# =============================================================================
#   2) Download archive and prepare the actual installation for changes
# =============================================================================
ECLIPSE_URL="${ECLIPSE_TARGZ_TEMPLATE//VERSION/$ECLIPSE_VERSION}"
ECLIPSE_URL="${ECLIPSE_URL//MILESTONE/$ECLIPSE_MILESTONE}"
ECLIPSE_URL="${ECLIPSE_URL//ARCH/$ECLIPSE_ARCH}"
APPLICATION_DIR="$BUILD_DIR/Eclipse-CPP-$ECLIPSE_VERSION-$ECLIPSE_MILESTONE"
APPLICATION_NAME="$(basename $APPLICATION_DIR)"

mkdir $BUILD_DIR
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

# TODO: Check whether this is available or not, if not add the property!
replaceStringInFile "$CONFIG_DIR/config.ini" "@user.home/workspace" \
    "@user.home/workspaces/eclipse-cpp-$ECLIPSE_VERSION-$ECLIPSE_MILESTONE"


# =============================================================================
#   4) Fix configuration: eclipse.ini with Java 21 runtime
# =============================================================================
ECLIPSE_INI="$APPLICATION_DIR/eclipse.ini"

replaceStringInFile "$ECLIPSE_INI" "-vmargs" \
    "-vm\n/usr/lib/jvm/java-21-openjdk-amd64/bin/java\n-vmargs"


# =============================================================================
#   5) Install necessary plug-ins for development
# =============================================================================
# TODO: Install required "org.eclipse.equinox.security" and then SonarLint
#if [[ -z ${SKIP_SONARLINT+x} ]]; then
#    $APPLICATION_DIR/eclipse -noSplash \
#        -application org.eclipse.equinox.p2.director \
#        -repository https://binaries.sonarsource.com/SonarLint-for-Eclipse/dogfood/ \
#        -installIU org.sonarlint.eclipse.feature.feature.group \
#        -profile SDKProfile \
#        -followReferences \
#        -destination $APPLICATION_DIR
#fi


# =============================================================================
#   6) Move to user application folder and delete old ones
# =============================================================================
APPLICATIONS_DIR="$HOME/applications"
if [[ ! -d "$APPLICATIONS_DIR" ]]; then
    mkdir -p $APPLICATIONS_DIR/$APPLICATION_NAME
fi

if ls $APPLICATIONS_DIR/Eclipse-CPP* >/dev/null 2>&1; then
    for cpp_installation in $APPLICATIONS_DIR/Eclipse-CPP*; do
        INSTALLATION_NAME="$(basename $cpp_installation)"
        rm -rf $cpp_installation
    done
fi

cp -r $APPLICATION_DIR $APPLICATIONS_DIR/$APPLICATION_NAME


# =============================================================================
#   7) Create desktop files and delete old ones
# =============================================================================
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/$APPLICATION_NAME.desktop"

if [[ ! -d "$DESKTOP_DIR" ]]; then
    mkdir -p $DESKTOP_DIR
fi

for cpp_installation in $DESKTOP_DIR/Eclipse-CPP*; do
    rm -f $cpp_installation
done

cp $DIR/Eclipse.desktop $DESKTOP_FILE

replaceStringInFile $DESKTOP_FILE "TPL_APPLICATION_NAME" "$APPLICATION_NAME"
replaceStringInFile $DESKTOP_FILE "TPL_HOME_DIR" "$HOME"


# =============================================================================
#   8) Update Gnome Desktop favorites
# =============================================================================
FAVORITES_DCONF="$(dconf read /org/gnome/shell/favorite-apps)"
FAVORITES_DCONF="${FAVORITES_DCONF#?}"
FAVORITES_DCONF="${FAVORITES_DCONF%?}"
IFS=', ' read -r -a FAVORITES <<< "$FAVORITES_DCONF"

NEW_FAVORITES="["
ALREADY_FOUND=false
for favorite in "${FAVORITES[@]}"; do
    if [[ "$favorite" == *"Eclipse-CPP"* ]]; then
        NEW_FAVORITES="$NEW_FAVORITES '$(basename $DESKTOP_FILE)',"
        ALREADY_FOUND=true
    else
        NEW_FAVORITES="$NEW_FAVORITES $favorite,"
    fi
done
if [[ $ALREADY_FOUND = false ]]; then
    NEW_FAVORITES="$NEW_FAVORITES '$(basename $DESKTOP_FILE)',"
fi
NEW_FAVORITES="${NEW_FAVORITES%?}]"

dconf write /org/gnome/shell/favorite-apps "$NEW_FAVORITES"
xdg-desktop-menu forceupdate
