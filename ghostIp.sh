#!/bin/bash

# ====================================
# AUTO IP & MAC ROTATION TOOL
# (Auto Detect Active Interface)
# ====================================

# ARGUMENTS:
# 1 = Stealth mode? (yes/no)
# 2 = Maximum rotations (0 = infinite)
# 3 = Random delay min (seconds)
# 4 = Random delay max (seconds)

STEALTH_MODE="${1:-no}" # yes / no
MAX_ROTATIONS="${2:-0}" # 0 = infinite
DELAY_MIN="${3:-1}"
DELAY_MAX="${4:-3}"
LOGFILE="/usr/local/bin/ghostIp.log"

# Terminal colors
RED="\033[1;31m"
GREEN="\033[1;32m"
NC="\033[0m" # reset color

# Ensure root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Please run the script as root!"
    echo "Example: sudo ./ghostIp.sh no 10 1 5"
    exit 1
fi

# Auto detect active network interface with IP and UP state
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

# Generate random MAC address
generate_mac() {
    hexchars="0123456789ABCDEF"
    echo "02$(for i in {1..5}; do echo -n :${hexchars:$((RANDOM % 16)):1}${hexchars:$((RANDOM % 16)):1}; done)"
}

# Check internet connectivity
check_internet() {
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get public IP and location info
get_public_info() {
    curl -s https://ipinfo.io | jq -r '.ip + " " + .city + ", " + .country'
}

# Log message function (respects stealth mode)
log_msg() {
    local MSG="$1"
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $MSG" >>$LOGFILE
    if [[ "$STEALTH_MODE" == "no" ]]; then
        echo -e "[$TIMESTAMP] $MSG"
    fi
}

COUNT=0
OLD_INFO=""
OLD_IP=""
OLD_LOC=""

# Main loop
while true; do
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Stop if rotation limit reached
    if [[ $MAX_ROTATIONS -ne 0 && $COUNT -ge $MAX_ROTATIONS ]]; then
        log_msg "[*] Rotation finished. Total rotations: $COUNT"
        exit 0
    fi

    # Get old public info (IP + location)
    OLD_INFO=$(get_public_info)
    OLD_IP=$(echo "$OLD_INFO" | awk '{print $1}')
    OLD_LOC=$(echo "$OLD_INFO" | cut -d' ' -f2-)

    # Disconnect interface
    log_msg "[*] Disconnecting interface $INTERFACE..."
    ip link set $INTERFACE down

    # Change MAC
    NEW_MAC=$(generate_mac)
    log_msg "[*] Changing MAC Address to $NEW_MAC"
    ip link set dev $INTERFACE address $NEW_MAC

    # Reconnect interface
    ip link set $INTERFACE up

    # Release & request new IP
    log_msg "[*] Releasing old IP..."
    dhclient -r $INTERFACE >/dev/null 2>&1
    log_msg "[*] Requesting new IP..."
    dhclient $INTERFACE >/dev/null 2>&1

    # Get new local IP
    NEW_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    # Check result
    if [ -z "$NEW_IP" ]; then
        log_msg "[!] Failed to obtain new local IP!"
    else
        if check_internet; then
            # Get new public info
            NEW_INFO=$(get_public_info)
            NEW_PUB_IP=$(echo "$NEW_INFO" | awk '{print $1}')
            NEW_LOC=$(echo "$NEW_INFO" | cut -d' ' -f2-)

            # Compare public IP
            if [[ "$OLD_IP" != "$NEW_PUB_IP" && -n "$NEW_PUB_IP" ]]; then
                PUB_CHANGE="${GREEN}[CHANGED]${NC}"
            else
                PUB_CHANGE="${RED}[NO CHANGE]${NC}"
            fi

            # Compare location
            if [[ "$OLD_LOC" != "$NEW_LOC" && -n "$NEW_LOC" ]]; then
                LOC_CHANGE="${GREEN}[CHANGED]${NC}"
            else
                LOC_CHANGE="${RED}[NO CHANGE]${NC}"
            fi

            # Log results
            log_msg "[+] Local IP: $NEW_IP (MAC: $NEW_MAC)"
            log_msg "[+] Old Public IP: $OLD_IP ($OLD_LOC)"
            log_msg "[+] New Public IP: $NEW_PUB_IP $PUB_CHANGE"
            log_msg "[+] Old Location: $OLD_LOC"
            log_msg "[+] New Location: $NEW_LOC $LOC_CHANGE"

            # Warning if public IP did not change (possible CGNAT)
            if [[ "$OLD_IP" == "$NEW_PUB_IP" ]]; then
                log_msg "[!] Warning: Public IP did not change. Your ISP may be using CGNAT."
            fi
        else
            log_msg "[!] Local IP: $NEW_IP but no internet connection detected!"
        fi
    fi

    ((COUNT++))

    # Random delay
    SLEEP_TIME=$((RANDOM % (DELAY_MAX - DELAY_MIN + 1) + DELAY_MIN))
    log_msg "[*] Waiting $SLEEP_TIME seconds before next rotation..."
    sleep $SLEEP_TIME
done
