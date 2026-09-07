#!/usr/bin/env bash
set -e

echo "perseus setup"
echo "============="

if [ -f user-config.nix ]; then
	echo "user-config.nix already exists."
	read -p "Overwrite? [y/N]: " OVERWRITE
	if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
		exit 0
	fi
fi

# ── Hardware detection ──────────────────────────────────────────────

GPU_DETECTED=false
LAPTOP_DETECTED=false
THUNDERBOLT_DETECTED=false

if grep -qi nvidia /sys/class/drm/card*/device/uevent 2>/dev/null; then
	GPU_DETECTED=true
fi
if [ -e /sys/class/power_supply/BAT0 ]; then
	LAPTOP_DETECTED=true
fi
if [ -d /sys/bus/thunderbolt ]; then
	THUNDERBOLT_DETECTED=true
fi

# ── Identity ────────────────────────────────────────────────────────

read -p "Username [$USER]: " USERNAME
USERNAME=${USERNAME:-$USER}

read -p "Hostname [perseus]: " HOST_NAME
HOST_NAME=${HOST_NAME:-perseus}

read -p "Full name (git): " GIT_NAME
read -p "Email (git): " GIT_EMAIL

# uid must be declared so the audit daemon can address the user's session bus.
# On an existing system, reuse the account's real uid; on a fresh install the
# account does not exist yet and NixOS will allocate 1000.
if id -u "$USERNAME" >/dev/null 2>&1; then
	USER_UID=$(id -u "$USERNAME")
else
	USER_UID=1000
fi
echo "uid: $USER_UID"

# ── Hardware toggles ────────────────────────────────────────────────

read -p "NVIDIA GPU? [$GPU_DETECTED]: " GPU_INPUT
HAS_GPU=${GPU_INPUT:-$GPU_DETECTED}

read -p "Laptop? [$LAPTOP_DETECTED]: " LAPTOP_INPUT
IS_LAPTOP=${LAPTOP_INPUT:-$LAPTOP_DETECTED}

read -p "Thunderbolt? [$THUNDERBOLT_DETECTED]: " TB_INPUT
THUNDERBOLT=${TB_INPUT:-$THUNDERBOLT_DETECTED}

# ── GPU bus IDs ─────────────────────────────────────────────────────

INTEL_BUS_ID=""
NVIDIA_BUS_ID=""

if [[ $HAS_GPU == "true" ]]; then
	echo "Detecting GPU bus IDs..."

	parse_pci_bus_id() {
		local raw=$1
		if [[ -z "$raw" ]]; then
			return
		fi
		local cleaned=$raw
		if [[ $(echo "$cleaned" | grep -o ':' | wc -l) -eq 2 ]]; then
			cleaned="${cleaned#*:}"
		fi
		IFS=':.' read -r bus dev func <<< "$cleaned"
		echo "PCI:$((16#$bus)):$((16#$dev)):$((16#$func))"
	}

	INTEL_RAW=$(lspci | grep -i "vga.*intel" | head -1 | cut -d' ' -f1)
	NVIDIA_RAW=$(lspci | grep -i "vga.*nvidia\|3d.*nvidia" | head -1 | cut -d' ' -f1)

	if [[ -n "$INTEL_RAW" ]]; then
		INTEL_BUS_ID=$(parse_pci_bus_id "$INTEL_RAW")
	fi
	if [[ -n "$NVIDIA_RAW" ]]; then
		NVIDIA_BUS_ID=$(parse_pci_bus_id "$NVIDIA_RAW")
	fi

	if [[ -z "$INTEL_BUS_ID" || -z "$NVIDIA_BUS_ID" ]]; then
		echo "Warning: Could not auto-detect GPU bus IDs."
		echo "Run 'lspci | grep -Ei \"vga|3d\"' to find them."
		if [[ -z "$INTEL_BUS_ID" ]]; then
			read -p "Intel bus ID (e.g. PCI:0:2:0): " INTEL_BUS_ID
		fi
		if [[ -z "$NVIDIA_BUS_ID" ]]; then
			read -p "NVIDIA bus ID (e.g. PCI:1:0:0): " NVIDIA_BUS_ID
		fi
	fi

	echo "Intel: $INTEL_BUS_ID"
	echo "NVIDIA: $NVIDIA_BUS_ID"
fi

# ── Browsers ────────────────────────────────────────────────────────

echo ""
echo "Browsers:"
read -p "  Firefox (hardened)? [Y/n]: " FF_INPUT
read -p "  Brave (plain package)? [y/N]: " BRAVE_INPUT

BROWSERS="["
if [[ ! $FF_INPUT =~ ^[Nn]$ ]]; then
	BROWSERS="$BROWSERS \"firefox\""
fi
if [[ $BRAVE_INPUT =~ ^[Yy]$ ]]; then
	BROWSERS="$BROWSERS \"brave\""
fi
BROWSERS="$BROWSERS ]"
BROWSERS=$(echo "$BROWSERS" | sed 's/\[ /[/g; s/ \]/]/g')

# ── Dev tools ───────────────────────────────────────────────────────

echo ""
echo "Development tools:"
read -p "  Python? [Y/n]: " PY_INPUT
read -p "  Go? [Y/n]: " GO_INPUT
read -p "  Rust? [y/N]: " RS_INPUT
read -p "  Node.js? [y/N]: " NODE_INPUT
read -p "  Android? [y/N]: " ANDROID_INPUT

DEVTOOLS="["
if [[ ! $PY_INPUT =~ ^[Nn]$ ]]; then
	DEVTOOLS="$DEVTOOLS \"python\""
fi
if [[ ! $GO_INPUT =~ ^[Nn]$ ]]; then
	DEVTOOLS="$DEVTOOLS \"go\""
fi
if [[ $RS_INPUT =~ ^[Yy]$ ]]; then
	DEVTOOLS="$DEVTOOLS \"rust\""
fi
if [[ $NODE_INPUT =~ ^[Yy]$ ]]; then
	DEVTOOLS="$DEVTOOLS \"node\""
fi
if [[ $ANDROID_INPUT =~ ^[Yy]$ ]]; then
	DEVTOOLS="$DEVTOOLS \"android\""
fi
DEVTOOLS="$DEVTOOLS ]"
DEVTOOLS=$(echo "$DEVTOOLS" | sed 's/\[ /[/g; s/ \]/]/g')

# ── Applications ────────────────────────────────────────────────────

echo ""
read -p "Email client (Thunderbird)? [Y/n]: " EMAIL_INPUT
EMAIL=true
if [[ $EMAIL_INPUT =~ ^[Nn]$ ]]; then
	EMAIL=false
fi

# ── VPN ─────────────────────────────────────────────────────────────

read -p "VPN support (Mullvad WireGuard)? [y/N]: " VPN_INPUT
VPN=false
if [[ $VPN_INPUT =~ ^[Yy]$ ]]; then
	VPN=true
fi

# ── Location ────────────────────────────────────────────────────────

echo ""
echo "Location (for blue light filter):"
echo "  1. US East Coast (New York)"
echo "  2. US West Coast (Los Angeles)"
echo "  3. Europe - Amsterdam"
echo "  4. Europe - London"
echo "  5. Asia - Tokyo"
echo "  6. Custom"
read -p "Choose [1-6]: " LOC

case $LOC in
	1) LAT=40.7; LON=-74.0; TZ="America/New_York" ;;
	2) LAT=34.0; LON=-118.2; TZ="America/Los_Angeles" ;;
	3) LAT=52.4; LON=4.9; TZ="Europe/Amsterdam" ;;
	4) LAT=51.5; LON=-0.1; TZ="Europe/London" ;;
	5) LAT=35.7; LON=139.7; TZ="Asia/Tokyo" ;;
	6) read -p "Latitude: " LAT; read -p "Longitude: " LON; read -p "Timezone: " TZ ;;
	*) LAT=52.4; LON=4.9; TZ="Europe/Amsterdam" ;;
esac

# ── Extra hosts (optional) ──────────────────────────────────────────

echo ""
read -p "Add custom /etc/hosts entries? [y/N]: " HOSTS_INPUT
EXTRA_HOSTS=""
if [[ $HOSTS_INPUT =~ ^[Yy]$ ]]; then
	echo "Enter entries as: IP hostname1 hostname2 ..."
	echo "Empty line to finish."
	while true; do
		read -p "  > " HOSTS_LINE
		if [[ -z "$HOSTS_LINE" ]]; then
			break
		fi
		HOST_IP=$(echo "$HOSTS_LINE" | awk '{print $1}')
		HOST_NAMES=$(echo "$HOSTS_LINE" | awk '{$1=""; print $0}' | xargs)
		NAMES_NIX=""
		for name in $HOST_NAMES; do
			NAMES_NIX="$NAMES_NIX \"$name\""
		done
		EXTRA_HOSTS="$EXTRA_HOSTS\n    \"$HOST_IP\" = [$NAMES_NIX ];"
	done
fi

# ── SSH keys ────────────────────────────────────────────────────────

echo ""
read -p "Add an SSH public key now? [y/N]: " SSH_INPUT
if [[ $SSH_INPUT =~ ^[Yy]$ ]]; then
	echo "Paste your SSH public key:"
	read -r SSH_KEY
	cat > modules/security/ssh-keys.nix << EOF
{
  $USERNAME = "$SSH_KEY";
}
EOF
	echo "  Created modules/security/ssh-keys.nix (sshd will be enabled on port 7889)"
else
	cat > modules/security/ssh-keys.nix << EOF
{
  # SSH public keys - add your keys here
  # $USERNAME = "ssh-ed25519 AAAAC3... your-email@example.com";
}
EOF
	echo "  Created empty modules/security/ssh-keys.nix (sshd stays disabled)"
fi

# ── Generate user-config.nix ────────────────────────────────────────

GPU_FIELDS=""
if [[ $HAS_GPU == "true" ]]; then
	GPU_FIELDS="
  intelBusId = \"$INTEL_BUS_ID\";
  nvidiaBusId = \"$NVIDIA_BUS_ID\";"
fi

HOSTS_BLOCK=""
if [[ -n "$EXTRA_HOSTS" ]]; then
	HOSTS_BLOCK="
  extraHosts = {$(echo -e "$EXTRA_HOSTS")
  };"
fi

cat > user-config.nix << EOF
# Perseus User Configuration
{
  # Identity
  username = "$USERNAME";
  uid = $USER_UID;
  hostname = "$HOST_NAME";
  gitName = "$GIT_NAME";
  gitEmail = "$GIT_EMAIL";

  # Hardware
  isLaptop = $IS_LAPTOP;
  hasGPU = $HAS_GPU;$GPU_FIELDS
  thunderbolt = $THUNDERBOLT;

  # Location
  timezone = "$TZ";
  latitude = $LAT;
  longitude = $LON;

  # Browsers
  browsers = $BROWSERS;

  # Development
  devTools = $DEVTOOLS;

  # Applications
  email = $EMAIL;

  # Network
  vpn = $VPN;$HOSTS_BLOCK

  # Appearance
  wallpaperPath = "assets/wallpaper.png";
  avatarPath = "assets/king.png";
}
EOF

echo ""
echo "  Wrote user-config.nix"

# ── Host hardware configuration ─────────────────────────────────────

HOST_DIR="hosts/default"
mkdir -p "$HOST_DIR"

if [ -f /etc/nixos/hardware-configuration.nix ]; then
	cp /etc/nixos/hardware-configuration.nix "$HOST_DIR/hardware-configuration.nix"
	echo "  Copied hardware-configuration.nix to $HOST_DIR/"
else
	echo "  Warning: /etc/nixos/hardware-configuration.nix not found."
	echo "  Copy it manually: cp /etc/nixos/hardware-configuration.nix $HOST_DIR/"
fi

# ── Git filters ─────────────────────────────────────────────────────
#
# These keep machine-specific and secret content out of commits. The clean
# filter replaces the working-tree content with a generic placeholder when
# staging; the smudge filter is a passthrough so your local file is untouched.
#
# Filters are registered in .git/config, which is per-clone and not versioned.
# Anyone who clones without running this script gets no filter at all.

echo ""
echo "Setting up git filters..."

grep -q "user-config.nix filter=userconfig" .gitattributes 2>/dev/null || echo "user-config.nix filter=userconfig" >> .gitattributes
grep -q "modules/security/ssh-keys.nix filter=sshkeys" .gitattributes 2>/dev/null || echo "modules/security/ssh-keys.nix filter=sshkeys" >> .gitattributes
grep -q "hosts/default/hardware-configuration.nix filter=hardware" .gitattributes 2>/dev/null || echo "hosts/default/hardware-configuration.nix filter=hardware" >> .gitattributes

git config filter.userconfig.clean 'cat << "CLEAN"
# Perseus User Configuration
{
  # Identity
  username = "user";
  uid = 1000;
  hostname = "perseus";
  gitName = "user";
  gitEmail = "user@example.com";

  # Hardware
  isLaptop = false;
  hasGPU = false;
  thunderbolt = false;

  # Location
  timezone = "Europe/Amsterdam";
  latitude = 52.4;
  longitude = 4.9;

  # Browsers
  browsers = [ "firefox" ];

  # Development
  devTools = [ "python" "go" ];

  # Applications
  email = true;

  # Network
  vpn = false;

  # Appearance
  wallpaperPath = "assets/wallpaper.png";
  avatarPath = "assets/king.png";
}
CLEAN'
git config filter.userconfig.smudge cat

git config filter.sshkeys.clean 'cat << "CLEAN"
{
  # SSH public keys - add your keys here
  # user = "ssh-ed25519 AAAAC3... your-email@example.com";
}
CLEAN'
git config filter.sshkeys.smudge cat

git config filter.hardware.clean 'cat hosts/default/hardware-configuration.ci.nix'
git config filter.hardware.smudge cat

git update-index --skip-worktree user-config.nix 2>/dev/null || true
git update-index --skip-worktree modules/security/ssh-keys.nix 2>/dev/null || true
git update-index --skip-worktree hosts/default/hardware-configuration.nix 2>/dev/null || true

echo "  Registered filters for user-config.nix, ssh-keys.nix, hardware-configuration.nix"

# ── Done ────────────────────────────────────────────────────────────

echo ""
echo "Setup complete."
echo ""
echo "Next steps:"
echo "  1. Review user-config.nix"
if [ ! -f "$HOST_DIR/hardware-configuration.nix" ]; then
	echo "  2. Copy hardware config: cp /etc/nixos/hardware-configuration.nix $HOST_DIR/"
	echo "  3. sudo nixos-rebuild switch --flake .#$HOST_NAME"
else
	echo "  2. sudo nixos-rebuild switch --flake .#$HOST_NAME"
fi

if [[ $HAS_GPU == "true" || $VPN == "true" ]]; then
	echo ""
	echo "First boot on new hardware: set hasGPU = false; and vpn = false; first,"
	echo "then enable them once the system boots successfully."
fi
