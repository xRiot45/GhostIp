#!/bin/bash

# ====================================
# GHOSTIP INSTALLER / UNINSTALLER / UPDATER
# ====================================

SCRIPT_NAME="ghostIp.sh"
INSTALL_PATH="/usr/local/bin"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/xRiot45/GhostIp/main/version.txt"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/xRiot45/GhostIp/main/$SCRIPT_NAME"
LOCAL_VERSION_FILE="$INSTALL_PATH/version.txt"
LOGFILE="$INSTALL_PATH/ghostIp.log"

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

# Help menu
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "===================================="
    echo "        GhostIP Installer"
    echo "===================================="
    echo "Usage:"
    echo "  sudo ./installer.sh"
    echo
    echo "Menu Options:"
    echo "  1) Install GhostIP"
    echo "     - Installs ghostIp.sh into $INSTALL_PATH"
    echo "     - Makes it executable"
    echo "     - Saves the version file"
    echo
    echo "  2) Uninstall GhostIP"
    echo "     - Removes ghostIp.sh, version file, and log file"
    echo
    echo "  3) Update GhostIP"
    echo "     - Checks GitHub for the latest version"
    echo "     - Downloads and replaces the installed script"
    echo
    echo "  4) Exit"
    echo "     - Quits the installer menu"
    echo
    echo "Example after installation:"
    echo "  sudo ghostIp.sh no 5 2 5"
    echo "  sudo ghostIp.sh yes 0 1 3 --skip-public-check"
    echo
    echo "GhostIP Flags:"
    echo "  --skip-public-check       Skip public IP and location check"
    echo "  --force-interface <iface> Force specific network interface"
    echo "  --no-mac-change           Rotate IP only, keep MAC unchanged"
    echo "  --log-to-file-only        Log to file only, suppress console output"
    echo
    exit 0
fi

# Ensure root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root!${NC}"
    echo "Example: sudo ./installer.sh"
    exit 1
fi

# Check dependencies
check_dependencies() {
    echo "Checking required dependencies..."
    for pkg in curl jq iproute2; do
        if ! command -v $pkg &>/dev/null; then
            echo "Installing missing dependency: $pkg"
            apt-get update -qq && apt-get install -y $pkg
        fi
    done
}

# Install GhostIP
install_ghostip() {
    echo "Installing GhostIP..."
    cp "$SCRIPT_NAME" "$INSTALL_PATH/$SCRIPT_NAME"
    chmod +x "$INSTALL_PATH/$SCRIPT_NAME"

    if [[ -f version.txt ]]; then
        cp version.txt "$LOCAL_VERSION_FILE"
    else
        echo "1.0.0" >"$LOCAL_VERSION_FILE"
    fi

    echo -e "${GREEN}GhostIP installed successfully!${NC}"
    echo "Run it with: sudo ghostIp.sh no 5 2 5"
    echo
    echo "Flags available:"
    echo "  --skip-public-check       Skip public IP and location check"
    echo "  --force-interface <iface> Force specific network interface"
    echo "  --no-mac-change           Rotate IP only, keep MAC unchanged"
    echo "  --log-to-file-only        Log to file only, suppress console output"
}

# Uninstall GhostIP
uninstall_ghostip() {
    echo "Uninstalling GhostIP..."
    rm -f "$INSTALL_PATH/$SCRIPT_NAME" "$LOCAL_VERSION_FILE" "$LOGFILE"
    echo -e "${RED}GhostIP has been removed from your system.${NC}"
}

# Update GhostIP
update_ghostip() {
    echo "Checking for updates..."
    if ! curl -s --head "$REMOTE_VERSION_URL" | grep "200" >/dev/null; then
        echo -e "${RED}Unable to check remote version.${NC}"
        exit 1
    fi

    REMOTE_VERSION=$(curl -s "$REMOTE_VERSION_URL")
    LOCAL_VERSION="0"

    if [[ -f "$LOCAL_VERSION_FILE" ]]; then
        LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE")
    fi

    if [[ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]]; then
        echo "Updating GhostIP from version $LOCAL_VERSION to $REMOTE_VERSION..."
        curl -s -o "$INSTALL_PATH/$SCRIPT_NAME" "$REMOTE_SCRIPT_URL"
        chmod +x "$INSTALL_PATH/$SCRIPT_NAME"
        echo "$REMOTE_VERSION" >"$LOCAL_VERSION_FILE"
        echo -e "${GREEN}Update complete!${NC}"
    else
        echo "GhostIP is already up-to-date (version $LOCAL_VERSION)."
    fi
}

# Menu
show_menu() {
    echo "=============================="
    echo "      GhostIP Installer       "
    echo "=============================="
    echo "1) Install GhostIP"
    echo "2) Uninstall GhostIP"
    echo "3) Update GhostIP"
    echo "4) Exit"
    echo "=============================="
    read -p "Choose an option [1-4]: " choice

    case $choice in
    1)
        check_dependencies
        install_ghostip
        ;;
    2)
        uninstall_ghostip
        ;;
    3)
        check_dependencies
        update_ghostip
        ;;
    4)
        exit 0
        ;;
    *)
        echo "Invalid choice!"
        ;;
    esac
}

show_menu
