set -euo pipefail

FLAKE="/etc/caldera/flake"
TARGET_HOST="caldera"
TARGET_USER="elyria"

echo "========================================"
echo "  Caldera Installer"
echo "========================================"
echo ""

# --- Step 1: Identify disk ---
echo "[1/4] Detecting NVMe drives..."
echo ""

# Find NVMe drives (not partitions, not eui aliases)
mapfile -t NVME_IDS < <(
	for f in /dev/disk/by-id/nvme-*; do
		[ -e "$f" ] || continue
		name=$(basename "$f")
		[[ $name == *part[0-9]* ]] && continue
		[[ $name == nvme-eui.* ]] && continue
		echo "$name"
	done | sort
)

if [ ${#NVME_IDS[@]} -eq 0 ]; then
	echo "ERROR: No NVMe drives found."
	echo "Check BIOS settings and ensure drives are in NVMe mode (not RAID)."
	exit 1
fi

echo "Available NVMe drives:"
echo ""
for i in "${!NVME_IDS[@]}"; do
	ID="${NVME_IDS[$i]}"
	DEV=$(readlink -f "/dev/disk/by-id/$ID")
	SIZE=$(lsblk -dno SIZE "$DEV" 2>/dev/null || echo "?")
	MODEL=$(lsblk -dno MODEL "$DEV" 2>/dev/null || echo "?")
	echo "  [$((i + 1))] $SIZE  $MODEL"
	echo "      $ID"
	echo ""
done

if [ ${#NVME_IDS[@]} -eq 1 ]; then
	echo "Only one NVMe drive found, selecting automatically."
	DISK="/dev/disk/by-id/${NVME_IDS[0]}"
else
	while true; do
		read -rp "Select drive [1-${#NVME_IDS[@]}]: " num
		idx=$((num - 1))
		if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#NVME_IDS[@]}" ]; then
			DISK="/dev/disk/by-id/${NVME_IDS[$idx]}"
			break
		fi
		echo "Invalid selection, try again."
	done
fi

DEV=$(readlink -f "$DISK")
SIZE=$(lsblk -dno SIZE "$DEV" 2>/dev/null || echo "?")
MODEL=$(lsblk -dno MODEL "$DEV" 2>/dev/null || echo "?")

echo ""
echo "Selected: $SIZE $MODEL"
echo "  $DISK"
echo ""

# --- Step 2: Partition with disko ---
echo "[2/4] Partitioning disk with disko..."
echo ""
echo "WARNING: This will ERASE:"
echo "  $DISK"
echo ""
read -rp "Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
	echo "Aborted."
	exit 1
fi

# Create writable copy (dereferences nix store symlinks)
WORK_DIR=$(mktemp -d)
rsync -rL --no-perms --no-owner --no-group \
	--exclude='.devenv' --exclude='.direnv' \
	"$FLAKE/" "$WORK_DIR/caldera/"

# Patch host.nix with actual disk ID
sed -i "s|/dev/disk/by-id/REPLACE-WITH-NVME-ID|$DISK|" \
	"$WORK_DIR/caldera/host.nix"

echo "Patched host.nix with disk: $DISK"
echo ""

# Run disko to partition and format
disko --mode disko --flake "$WORK_DIR/caldera#$TARGET_HOST"

echo "Disk partitioned and formatted."

# --- Step 3: Install NixOS ---
echo "[3/4] Installing NixOS..."
echo ""
echo "The target system closure is pre-cached in this ISO."
echo "This should complete without needing to download anything."
echo ""

nixos-install --flake "$WORK_DIR/caldera#$TARGET_HOST" --no-root-passwd

# --- Step 4: Place flake for future rebuilds ---
echo "[4/4] Installing flake to ~/.config/caldera..."

USER_HOME="/mnt/home/$TARGET_USER"
CALDERA_DIR="$USER_HOME/.config/caldera"
mkdir -p "$CALDERA_DIR"

# Copy the patched flake (with correct disk ID baked in)
rsync -rL --no-perms --no-owner --no-group "$WORK_DIR/caldera/" "$CALDERA_DIR/"

# Initialize as a git repo so nix flake commands work
cd "$CALDERA_DIR"
git init
git add -A
git commit -m "Initial caldera configuration (from installer)"

# Fix ownership (nixos-install creates home as root)
chown -R 1000:100 "$USER_HOME/.config"

echo "Flake installed at $CALDERA_DIR"

# --- Done ---
rm -rf "$WORK_DIR"

echo ""
echo "========================================"
echo "  Installation complete!"
echo ""
echo "  Default user: elyria"
echo "  Default password: caldera"
echo "  (change it immediately with: passwd)"
echo ""
echo "  Flake location: ~/.config/caldera"
echo "  Rebuild: rebuild"
echo "  Upgrade: upgrade"
echo ""
echo "  Remove the USB and reboot."
echo "========================================"
