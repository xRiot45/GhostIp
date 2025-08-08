#!/bin/bash

STEALTH_MODE="${1:-no}"
MAX_ROTATIONS="${2:-0}"
DELAY_MIN="${3:-1}"
DELAY_MAX="${4:-3}"
LOGFILE="/usr/local/bin/ghostIp.log"

# parse flags after 4 positional
shift 4 || true
SKIP_PUBLIC_CHECK=false
FORCE_INTERFACE=""
NO_MAC_CHANGE=false
LOG_FILE_ONLY=false
TOR_CONTROL_PASS="${TOR_CONTROL_PASS:-}"
USE_TOR=true

while [[ $# -gt 0 ]]; do
    case "$1" in
    --skip-public-check)
        SKIP_PUBLIC_CHECK=true
        shift
        ;;
    --force-interface)
        FORCE_INTERFACE="$2"
        shift 2
        ;;
    --no-mac-change)
        NO_MAC_CHANGE=true
        shift
        ;;
    --log-to-file-only)
        LOG_FILE_ONLY=true
        shift
        ;;
    --tor-pass)
        TOR_CONTROL_PASS="$2"
        shift 2
        ;;
    --no-tor)
        USE_TOR=false
        shift
        ;;
    *) shift ;;
    esac
done

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
NC="\033[0m"

# require root
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root (sudo)."
    exit 1
fi

# Check dependencies
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1"
        exit 1
    }
}
require_cmd ip
require_cmd dhclient
require_cmd curl
require_cmd jq
require_cmd nc

# check optional tools
PROXYCHAINS_CMD=""
if command -v proxychains4 >/dev/null 2>&1; then
    PROXYCHAINS_CMD="proxychains4"
elif command -v torsocks >/dev/null 2>&1; then
    PROXYCHAINS_CMD="torsocks"
fi

if $USE_TOR; then
    require_cmd tor
    if systemctl is-enabled --quiet tor 2>/dev/null || systemctl status tor >/dev/null 2>&1; then
        systemctl start tor 2>/dev/null || true
    fi
fi

# detect interface
if [[ -n "$FORCE_INTERFACE" ]]; then
    INTERFACE="$FORCE_INTERFACE"
else
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
        if ip addr show "$iface" | grep -q "inet "; then
            state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "down")
            if [[ "$state" == "up" ]]; then
                echo "$iface"
                break
            fi
        fi
    done)
fi

if [[ -z "$INTERFACE" ]]; then
    echo "No active network interface found."
    exit 1
fi

# generate mac
generate_mac() {
    hexchars="0123456789ABCDEF"
    mac="02"
    for i in {1..5}; do
        a=${hexchars:$((RANDOM % 16)):1}
        b=${hexchars:$((RANDOM % 16)):1}
        mac+=":${a}${b}"
    done
    echo "$mac"
}

log_msg() {
    local MSG="$1"
    local TS
    TS=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TS] $MSG" >>"$LOGFILE"
    if [[ "$STEALTH_MODE" == "no" && "$LOG_FILE_ONLY" == false ]]; then
        # color output for console
        if [[ "$MSG" == \[WARNING\]* ]]; then
            echo -e "${RED}[$TS] $MSG${NC}"
        elif [[ "$MSG" == \[INFO\]* ]]; then
            echo -e "${GREEN}[$TS] $MSG${NC}"
        else
            echo "[$TS] $MSG"
        fi
    fi
}

# Check internet (direct)
check_internet() {
    ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1
}

# Get public IP via direct (uses ipinfo.io)
get_public_direct() {
    curl -s --max-time 8 https://ipinfo.io | jq -r '.ip // empty'
}

# Get public IP via Tor (proxychains/torsocks preferred)
get_public_via_tor() {
    if [[ -z "$PROXYCHAINS_CMD" ]]; then
        # fallback use curl SOCKS5 directly if Tor on localhost:9050
        curl -s --socks5-hostname 127.0.0.1:9050 --max-time 12 https://ipinfo.io | jq -r '.ip // empty'
    else
        $PROXYCHAINS_CMD curl -s --max-time 12 https://ipinfo.io | jq -r '.ip // empty'
    fi
}

# Tor NEWNYM via ControlPort
tor_newnym() {
    if ! $USE_TOR; then
        log_msg "[INFO] --no-tor set, skipping Tor NEWNYM."
        return 0
    fi

    if [[ -z "$TOR_CONTROL_PASS" ]]; then
        log_msg "[WARNING] Tor control password not set (TOR_CONTROL_PASS or --tor-pass). Cannot AUTH. Trying cookie auth..."
        # attempt cookie auth (requires CookieAuthentication 1 and tor on same host)
        # try SIGNAL NEWNYM without auth (most tor configs won't allow)
        printf 'SIGNAL NEWNYM\n' | nc 127.0.0.1 9051 >/dev/null 2>&1 || {
            log_msg "[WARNING] CONTROL: unable to signal via cookie/no-auth. Tor control likely requires password."
            return 1
        }
        log_msg "[INFO] SIGNED NEWNYM (no password) - please verify."
        return 0
    fi

    # send AUTH and SIGNAL NEWNYM
    AUTH_SEQ=$(printf 'AUTHENTICATE "%s"\nSIGNAL NEWNYM\nQUIT\n' "$TOR_CONTROL_PASS")
    printf "%s" "$AUTH_SEQ" | nc 127.0.0.1 9051 >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log_msg "[WARNING] Failed to send NEWNYM to Tor control port (check password and torctl)."
        return 1
    fi
    # give Tor a moment to build new circuits
    sleep 5
    return 0
}

COUNT=0

# main loop
while true; do
    if [[ $MAX_ROTATIONS -ne 0 && $COUNT -ge $MAX_ROTATIONS ]]; then
        log_msg "[INFO] Rotation finished. Total rotations: $COUNT"
        exit 0
    fi

    # old public info
    if [[ "$SKIP_PUBLIC_CHECK" == false ]]; then
        OLD_PUB=$(get_public_direct)
        OLD_PUB_TOR=$($USE_TOR && get_public_via_tor || echo "")
    fi

    log_msg "[INFO] Disconnecting interface $INTERFACE..."
    ip link set "$INTERFACE" down || log_msg "[WARNING] Failed to set $INTERFACE down"

    if [[ "$NO_MAC_CHANGE" == false ]]; then
        NEW_MAC=$(generate_mac)
        log_msg "[INFO] Changing MAC to $NEW_MAC"
        ip link set dev "$INTERFACE" address "$NEW_MAC" || log_msg "[WARNING] Could not set MAC (maybe managed by NetworkManager)"
    else
        NEW_MAC=$(cat /sys/class/net/"$INTERFACE"/address 2>/dev/null || echo "unknown")
        log_msg "[INFO] Keeping MAC: $NEW_MAC"
    fi

    ip link set "$INTERFACE" up || log_msg "[WARNING] Failed to set $INTERFACE up"

    log_msg "[INFO] Releasing DHCP on $INTERFACE..."
    dhclient -r "$INTERFACE" >/dev/null 2>&1 || log_msg "[WARNING] dhclient -r failed"

    log_msg "[INFO] Requesting DHCP on $INTERFACE..."
    dhclient "$INTERFACE" >/dev/null 2>&1 || log_msg "[WARNING] dhclient request may have failed"

    NEW_LOCAL_IP=$(ip -4 addr show dev "$INTERFACE" | awk '/inet /{print $2}' | cut -d/ -f1 || true)
    if [[ -z "$NEW_LOCAL_IP" ]]; then
        log_msg "[WARNING] Could not obtain local IP for $INTERFACE"
    else
        log_msg "[INFO] New local IP: $NEW_LOCAL_IP (MAC: $NEW_MAC)"
    fi

    # ensure internet before Tor / checks
    if check_internet; then
        if [[ "$USE_TOR" == true ]]; then
            # request new Tor circuit
            log_msg "[INFO] Requesting Tor NEWNYM (new circuit)..."
            if tor_newnym; then
                log_msg "[INFO] Tor NEWNYM requested."
            else
                log_msg "[WARNING] Tor NEWNYM failed or not authorized."
            fi
        fi

        if [[ "$SKIP_PUBLIC_CHECK" == false ]]; then
            # get new public IP direct & via tor
            NEW_PUB=$(get_public_direct)
            if [[ "$USE_TOR" == true ]]; then
                NEW_PUB_TOR=$(get_public_via_tor)
            else
                NEW_PUB_TOR=""
            fi

            PUB_CHANGE_DIRECT="[NO CHANGE]"
            PUB_CHANGE_TOR="[NO CHANGE]"
            if [[ -n "$OLD_PUB" && -n "$NEW_PUB" && "$OLD_PUB" != "$NEW_PUB" ]]; then
                PUB_CHANGE_DIRECT="[CHANGED]"
            fi
            if [[ -n "$OLD_PUB_TOR" && -n "$NEW_PUB_TOR" && "$OLD_PUB_TOR" != "$NEW_PUB_TOR" ]]; then
                PUB_CHANGE_TOR="[CHANGED]"
            fi

            log_msg "[INFO] Old public IP (direct): ${OLD_PUB:-unknown}"
            log_msg "[INFO] New public IP (direct): ${NEW_PUB:-unknown} ${PUB_CHANGE_DIRECT}"
            if [[ "$USE_TOR" == true ]]; then
                log_msg "[INFO] Old public IP (via Tor): ${OLD_PUB_TOR:-unknown}"
                log_msg "[INFO] New public IP (via Tor): ${NEW_PUB_TOR:-unknown} ${PUB_CHANGE_TOR}"
                if [[ -z "$NEW_PUB_TOR" ]]; then
                    log_msg "[WARNING] Could not retrieve public IP via Tor. Check Tor and proxychains/torsocks."
                fi
            fi

            # possible CGNAT warning
            if [[ -n "$OLD_PUB" && -n "$NEW_PUB" && "$OLD_PUB" == "$NEW_PUB" ]]; then
                log_msg "[WARNING] Public IP (direct) did not change. ISP may use CGNAT or IP is sticky."
            fi
        fi
    else
        log_msg "[WARNING] No internet connectivity after DHCP. Skipping public checks."
    fi

    ((COUNT++))

    # Random sleep between rotations
    if [[ $DELAY_MAX -lt $DELAY_MIN ]]; then
        SLEEP_TIME="$DELAY_MIN"
    else
        RANGE=$((DELAY_MAX - DELAY_MIN + 1))
        SLEEP_TIME=$((RANDOM % RANGE + DELAY_MIN))
    fi
    log_msg "[INFO] Waiting $SLEEP_TIME seconds before next rotation..."
    sleep "$SLEEP_TIME"
done
