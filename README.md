# GhostIP

GhostIP is an automated tool to rotate your IP and MAC address on Linux systems, useful for penetration testing, anonymization, or bypassing IP-based rate limits.

---

## Features

* **Auto-detect active network interface**: No need to specify manually, the script finds the active one.
* **Random MAC address & IP rotation**: Prevent tracking by changing MAC and requesting a new DHCP lease.
* **Public IP & Geolocation Check**: Uses [ipinfo.io](https://ipinfo.io) to display old vs new public IP and location.
* **Stealth Mode**: Logs silently without printing to the terminal (for background usage).
* **Color-coded Logs**: `INFO` (green) and `WARNING` (red) messages for better visibility.
* **CGNAT Detection**: Warns you if your public IP does not change (common with mobile carriers).
* **Installer & Auto-Updater**: Easy install/uninstall and update from GitHub repository.
* **Skip Public Check Option**: Faster rotation when public IP check is not needed.

---

## Repository Structure

```
ghostip/
├── ghostIp.sh           # Main script for IP & MAC rotation
├── installer.sh         # Installer, uninstaller, and updater script
├── version.txt          # Holds the latest version number
├── README.md            # Documentation (this file)
└── LICENSE              # License file (MIT recommended)
```

---

## Installation

1. **Clone the repository:**

```bash
git clone https://github.com/xRiot45/GhostIp.git
cd GhostIp
```

2. **Make scripts executable:**

```bash
chmod +x ghostIp.sh installer.sh
```

3. **Run the installer:**

```bash
sudo ./installer.sh
```

4. **Follow menu options to install GhostIP.**

---

## Usage

After installation, you can run GhostIP directly:

```bash
sudo ghostIp.sh no 10 1 5
```

### **Arguments**

1. `Stealth mode`: `yes` or `no`
2. `Maximum rotations`: `0` = infinite loop
3. `Minimum delay`: in seconds
4. `Maximum delay`: in seconds

**Example:**

```bash
sudo ghostIp.sh no 5 2 5
```

This will rotate IP and MAC **5 times** with random delay between **2–5 seconds**.

---

### **Optional Flags**

* `--skip-public-check` : Skips public IP and geolocation check (faster rotation).
* `--force-interface <iface>` : Force specific interface (e.g., `--force-interface wlan0`).
* `--no-mac-change` : Only rotates IP without changing MAC.
* `--log-to-file-only` : Suppress console output, log to file only.

---

## Auto-Update

To check and apply updates from the repository:

```bash
sudo ./installer.sh
```

Choose option **`3) Update GhostIP`**.

The script compares your local `version.txt` with the remote version in the repository and updates automatically.

---

## Uninstallation

Run the installer and choose uninstall option:

```bash
sudo ./installer.sh
```

Select **`2) Uninstall GhostIP`** to remove all files and logs.

---

## Logs

Logs are stored in:

```
/usr/local/bin/ghostIp.log
```

**Color codes:**

* **INFO (green):** Normal operations
* **WARNING (red):** Issues like failed IP change or no internet

### Example Log Output

```
[2025-08-03 16:10:05] [INFO] Disconnecting interface wlxec086b18f384...
[2025-08-03 16:10:05] [INFO] Changing MAC Address to 02:1E:A3:CA:AD:35
[2025-08-03 16:10:05] [INFO] Releasing old IP...
[2025-08-03 16:10:05] [INFO] Requesting new IP...
[2025-08-03 16:10:12] [INFO] Local IP: 192.168.18.126 (MAC: 02:1E:A3:CA:AD:35)
[2025-08-03 16:10:12] [INFO] Old Public IP: 118.99.64.211 (Pontianak, ID)
[2025-08-03 16:10:12] [INFO] New Public IP: 118.99.64.211 [NO CHANGE]
[2025-08-03 16:10:12] [WARNING] Detected possible CGNAT: Public IP hasn't changed.
[2025-08-03 16:10:12] [INFO] Waiting 3 seconds before next rotation...
```

---

## Requirements

* Linux (Debian, Ubuntu, Kali recommended)
* Packages: `curl`, `jq`, `iproute2`

The installer automatically checks and installs missing dependencies.

---

## Troubleshooting

* If **public IP does not change**, your ISP may be using **CGNAT**. In this case, use VPN or TOR mode in future releases.
* Ensure you run the script as **root**:

  ```bash
  sudo ghostIp.sh no 10 1 5
  ```
* Check **network interface** with:

  ```bash
  ip a
  ```
* Use `--force-interface` if auto-detection fails:

  ```bash
  sudo ghostIp.sh no 10 1 5 --force-interface wlo1
  ```

---

## License

MIT License (see LICENSE file for details).
