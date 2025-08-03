#!/bin/bash

# ===============================
# GhostIP Installer / Uninstaller / Updater
# ===============================

INSTALL_PATH="/usr/local/bin"
SCRIPT_NAME="ghostIp.sh"
LOG_PATH="/usr/local/bin/ghostIp.log"
VERSION_FILE="/usr/local/bin/ghostIp.version"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/xRiot45/GhostIp/main/version.txt"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/xRiot45/GhostIp/main/ghostIp.sh"

GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

menu() {
    echo -e "${GREEN}GhostIP Tool Manager${NC}"
    echo "1) Install GhostIP"
    echo "2) Uninstall GhostIP"
    echo "3) Update GhostIP"
    echo "4) Exit"
    read -p "Choose an option [1-4]: " OPTION
}

install_ghostip() {
    echo -e "${GREEN}Starting installation...${NC}"

    # Install dependencies
    for pkg in curl jq iproute2; do
        if ! command -v $pkg &>/dev/null; then
            echo -e "${GREEN}Installing $pkg...${NC}"
            apt update && apt install -y $pkg
        fi
    done

    # Copy script
    if [ -f "$SCRIPT_NAME" ]; then
        cp "$SCRIPT_NAME" "$INSTALL_PATH/$SCRIPT_NAME"
        chmod +x "$INSTALL_PATH/$SCRIPT_NAME"
        echo -e "${GREEN}GhostIP installed to $INSTALL_PATH/$SCRIPT_NAME${NC}"
    else
        echo -e "${RED}Error: $SCRIPT_NAME not found in current directory.${NC}"
        exit 1
    fi

    # Save version
    if grep -q "VERSION=" "$SCRIPT_NAME"; then
        VERSION=$(grep "VERSION=" "$SCRIPT_NAME" | cut -d'"' -f2)
        echo "$VERSION" >"$VERSION_FILE"
    fi

    # Create log file
    if [ ! -f "$LOG_PATH" ]; then
        touch "$LOG_PATH"
        chmod 666 "$LOG_PATH"
        echo -e "${GREEN}Log file created at $LOG_PATH${NC}"
    fi

    echo -e "${GREEN}Installation complete!${NC}"
    echo "Run: sudo ghostIp.sh no 10 1 5"
}

uninstall_ghostip() {
    echo -e "${RED}Uninstalling GhostIP...${NC}"

    if [ -f "$INSTALL_PATH/$SCRIPT_NAME" ]; then
        rm "$INSTALL_PATH/$SCRIPT_NAME"
        echo -e "${GREEN}Removed $INSTALL_PATH/$SCRIPT_NAME${NC}"
    fi

    if [ -f "$LOG_PATH" ]; then
        rm "$LOG_PATH"
        echo -e "${GREEN}Removed $LOG_PATH${NC}"
    fi

    if [ -f "$VERSION_FILE" ]; then
        rm "$VERSION_FILE"
        echo -e "${GREEN}Removed version file${NC}"
    fi

    echo -e "${GREEN}GhostIP successfully uninstalled.${NC}"
}

update_ghostip() {
    echo -e "${GREEN}Checking for updates...${NC}"

    # Check if installed
    if [ ! -f "$INSTALL_PATH/$SCRIPT_NAME" ]; then
        echo -e "${RED}GhostIP is not installed!${NC}"
        exit 1
    fi

    # Get local version
    LOCAL_VERSION="0.0.0"
    if [ -f "$VERSION_FILE" ]; then
        LOCAL_VERSION=$(cat "$VERSION_FILE")
    fi

    # Get remote version
    REMOTE_VERSION=$(curl -s "$REMOTE_VERSION_URL")

    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}Failed to check remote version.${NC}"
        exit 1
    fi

    if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}New version available: $REMOTE_VERSION (Current: $LOCAL_VERSION)${NC}"
        echo -e "${GREEN}Updating...${NC}"

        # Download new script
        curl -s -o "$INSTALL_PATH/$SCRIPT_NAME" "$REMOTE_SCRIPT_URL"
        chmod +x "$INSTALL_PATH/$SCRIPT_NAME"

        # Update version file
        echo "$REMOTE_VERSION" >"$VERSION_FILE"

        echo -e "${GREEN}Update complete!${NC}"
    else
        echo -e "${GREEN}You already have the latest version ($LOCAL_VERSION).${NC}"
    fi
}

# Run menu
menu
case $OPTION in
1) install_ghostip ;;
2) uninstall_ghostip ;;
3) update_ghostip ;;
4) echo "Exiting..." ;;
*) echo -e "${RED}Invalid option.${NC}" ;;
esac
