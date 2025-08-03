#!/bin/bash
VERSION="1.1.0"

# ====================================
# AUTO IP & MAC ROTATION TOOL
# (CGNAT Detection + Skip Public Check Option)
# ====================================

# ARGUMENTS:
# 1 = Stealth mode? (yes/no)
# 2 = Maximum rotations (0 = infinite)
# 3 = Random delay min (seconds)
# 4 = Random delay max (seconds)
# 5 = Extra flag (e.g., --skip-public-check)

STEALTH_MODE="${1:-no}" # yes / no
MAX_ROTATIONS="${2:-0}" # 0 = infinite
DELAY_MIN="${3:-1}"
DELAY_MAX="${4:-3}"
EXTRA_FLAG="${5:-}"

LOGFILE="/usr/local/bin/ip-rotation.log"

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Check skip public check flag
SKIP_PUBLIC_CHECK=false
if [[ "$EXTRA_FLAG" == "--skip-public-check" ]]; then
    SKIP_PUBLIC_CHECK=true
fi

# Ensure root
if [[ $EUID -ne 0 ]]; then
    echo "Please run the script as root!"
    echo "Usage: sudo ./ghostIp.sh no 10 1 5 [--skip-public-check]"
    exit 1
fi

# Detect active interface
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
    if ip addr show "$iface" | grep -q "inet "; then
        state=$(cat /sys/class/net/$iface/operstate)
        if [[ "$state" == "up" ]]; then
            echo "$iface"
            break
        fi
    fi
done)

if [ -z "$INTERFACE" ]; then
    echo "No active network interface with IP found!"
    exit 1
fi

# Functions
generate_mac() {
    hexchars="0123456789ABCDEF"
    echo "02$(for i in {1..5}; do echo -n :${hexchars:$((RANDOM % 16)):1}${hexchars:$((RANDOM % 16)):1}; done)"
}

check_internet() {
    ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1
}

get_public_info() {
    curl -s https://ipinfo.io | jq -r '.ip + " " + .city + ", " + .country'
}

log_msg() {
    local MSG="$1"
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Colorize INFO/WARNING
    if [[ "$MSG" == \[INFO\]* ]]; then
        MSG="${GREEN}$MSG${NC}"
    elif [[ "$MSG" == \[WARNING\]* ]]; then
        MSG="${RED}$MSG${NC}"
    fi

    echo "[$TIMESTAMP] $MSG" >>$LOGFILE
    [[ "$STEALTH_MODE" == "no" ]] && echo -e "[$TIMESTAMP] $MSG"
}

# CGNAT detection variable
CGNAT_WARNING_COUNT=0
CGNAT_THRESHOLD=3 # Warn after 3 consecutive same public IP

COUNT=0
OLD_INFO=""
OLD_IP=""
OLD_LOC=""

# Main loop
while true; do
    if [[ $MAX_ROTATIONS -ne 0 && $COUNT -ge $MAX_ROTATIONS ]]; then
        log_msg "[INFO] Rotation finished. Total rotations: $COUNT"
        exit 0
    fi

    # Skip public check if flag enabled
    if ! $SKIP_PUBLIC_CHECK; then
        OLD_INFO=$(get_public_info)
        OLD_IP=$(echo "$OLD_INFO" | awk '{print $1}')
        OLD_LOC=$(echo "$OLD_INFO" | cut -d' ' -f2-)
    fi

    # Disconnect interface
    log_msg "[INFO] Disconnecting interface $INTERFACE..."
    ip link set $INTERFACE down

    # Change MAC
    NEW_MAC=$(generate_mac)
    log_msg "[INFO] Changing MAC Address to $NEW_MAC"
    ip link set dev $INTERFACE address $NEW_MAC

    # Reconnect interface
    ip link set $INTERFACE up

    # Release & request new IP
    log_msg "[INFO] Releasing old IP..."
    dhclient -r $INTERFACE >/dev/null 2>&1
    log_msg "[INFO] Requesting new IP..."
    dhclient $INTERFACE >/dev/null 2>&1

    NEW_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    if [ -z "$NEW_IP" ]; then
        log_msg "[WARNING] Failed to obtain new local IP!"
    else
        if check_internet; then
            if ! $SKIP_PUBLIC_CHECK; then
                NEW_INFO=$(get_public_info)
                NEW_PUB_IP=$(echo "$NEW_INFO" | awk '{print $1}')
                NEW_LOC=$(echo "$NEW_INFO" | cut -d' ' -f2-)

                if [[ "$OLD_IP" != "$NEW_PUB_IP" && -n "$NEW_PUB_IP" ]]; then
                    PUB_CHANGE="${GREEN}[CHANGED]${NC}"
                    CGNAT_WARNING_COUNT=0
                else
                    PUB_CHANGE="${RED}[NO CHANGE]${NC}"
                    ((CGNAT_WARNING_COUNT++))
                fi

                log_msg "[INFO] Local IP: $NEW_IP (MAC: $NEW_MAC)"
                log_msg "[INFO] Old Public IP: $OLD_IP ($OLD_LOC)"
                log_msg "[INFO] New Public IP: $NEW_PUB_IP $PUB_CHANGE"
                log_msg "[INFO] Old Location: $OLD_LOC"
                log_msg "[INFO] New Location: $NEW_LOC"

                if [[ $CGNAT_WARNING_COUNT -ge $CGNAT_THRESHOLD ]]; then
                    log_msg "[WARNING] Detected possible CGNAT: Public IP hasn't changed for $CGNAT_WARNING_COUNT rotations. Consider using VPN/TOR."
                fi
            else
                log_msg "[INFO] Local IP rotated: $NEW_IP (MAC: $NEW_MAC) - Public check skipped"
            fi
        else
            log_msg "[WARNING] Local IP: $NEW_IP but no internet connection detected!"
        fi
    fi

    ((COUNT++))

    # Random delay
    SLEEP_TIME=$((RANDOM % (DELAY_MAX - DELAY_MIN + 1) + DELAY_MIN))
    log_msg "[INFO] Waiting $SLEEP_TIME seconds before next rotation..."
    sleep $SLEEP_TIME
done
