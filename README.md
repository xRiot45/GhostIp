# GhostIP

GhostIP is an automated tool to rotate your IP and MAC address on Linux systems, useful for penetration testing, anonymization, or bypassing IP-based rate limits.

---

## Features

* Auto-detect active network interface.
* Random MAC address and IP rotation.
* Public IP and geolocation check (via ipinfo.io).
* Stealth mode for silent logging.
* Detailed logs with color-coded indicators (INFO/WARNING).
* Easy installation, uninstallation, and auto-update support.

---

## Repository Structure

```
ghostip/
├── ghostIp.sh           # Main script for IP & MAC rotation
├── installer.sh         # Installer, uninstaller, and updater script
├── README.md            # Documentation (this file)
└── LICENSE              # License file (MIT recommended)
```

---

## Installation

1. Clone the repository:

```bash
git clone https://github.com/xRiot45/GhostIp.git
cd GhostIp
```

2. Make scripts executable:

```bash
chmod +x ghostIp.sh installer.sh
```

3. Run the installer:

```bash
sudo ./installer.sh
```

4. Follow the menu options to install GhostIP.

---

## Usage

After installation, you can run GhostIP directly:

```bash
sudo ghostIp.sh no 10 1 5
```

**Arguments:**

* `1` = Stealth mode (`yes` or `no`)
* `2` = Maximum rotations (`0` = infinite)
* `3` = Minimum delay (seconds)
* `4` = Maximum delay (seconds)

Example:

```bash
sudo ghostIp.sh no 5 2 5
```

This will rotate IP and MAC 5 times with a random delay between 2–5 seconds.

---

## Auto-Update

To check and apply updates from the repository:

```bash
sudo ./installer.sh
```

Choose option `3) Update GhostIP`.

The script compares your local version with the `version.txt` in the repository and updates automatically if a new version is available.

---

## Uninstallation

Run the installer and choose the uninstall option:

```bash
sudo ./installer.sh
```

Select `2) Uninstall GhostIP` to remove all files and logs.

---

## Logs

Logs are stored in:

```
/usr/local/bin/ghostIp.log
```

Color codes:

* **INFO (green):** Normal operations
* **WARNING (red):** Issues like failed IP change or no internet

---

## Requirements

* Linux (Debian, Ubuntu, Kali recommended)
* Packages: `curl`, `jq`, `iproute2`

Installer will automatically install missing dependencies.

---

## License

MIT License (see LICENSE file for details).
