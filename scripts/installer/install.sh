set -euo pipefail

FLAKE="/etc/caldera/flake"
TARGET_USER="operator"

# Pre-flight checks
if [ ! -f /etc/caldera/system-closure ]; then
	echo "ERROR: System closure not found at /etc/caldera/system-closure"
	echo "This script must be run from the Caldera installer ISO."
	exit 1
fi

SYSTEM_CLOSURE=$(cat /etc/caldera/system-closure)

echo "========================================"
echo "  Caldera Installer"
echo "========================================"
echo ""

# --- Step 1: Identify disk ---
echo "[1/4] Detecting drives..."
echo ""

# Find SATA and NVMe drives (not partitions, not eui aliases)
mapfile -t DISK_IDS < <(
	for f in /dev/disk/by-id/ata-* /dev/disk/by-id/nvme-*; do
		[ -e "$f" ] || continue
		name=$(basename "$f")
		[[ $name == *part[0-9]* ]] && continue
		[[ $name == nvme-eui.* ]] && continue
		echo "$name"
	done | sort
)

if [ ${#DISK_IDS[@]} -eq 0 ]; then
	echo "ERROR: No drives found."
	echo "Check BIOS settings and ensure drives are visible."
	exit 1
fi

echo "Available drives:"
echo ""
for i in "${!DISK_IDS[@]}"; do
	ID="${DISK_IDS[$i]}"
	DEV=$(readlink -f "/dev/disk/by-id/$ID")
	SIZE=$(lsblk -dno SIZE "$DEV" 2>/dev/null || echo "?")
	MODEL=$(lsblk -dno MODEL "$DEV" 2>/dev/null || echo "?")
	echo "  [$((i + 1))] $SIZE  $MODEL"
	echo "      $ID"
	echo ""
done

if [ ${#DISK_IDS[@]} -eq 1 ]; then
	echo "Only one drive found, selecting automatically."
	DISK="/dev/disk/by-id/${DISK_IDS[0]}"
else
	while true; do
		read -rp "Select drive [1-${#DISK_IDS[@]}]: " num
		idx=$((num - 1))
		if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#DISK_IDS[@]}" ]; then
			DISK="/dev/disk/by-id/${DISK_IDS[$idx]}"
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

# --- Step 2: Partition and format ---
echo "[2/4] Partitioning and formatting..."
echo ""
echo "WARNING: This will ERASE:"
echo "  $DISK"
echo ""
read -rp "Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
	echo "Aborted."
	exit 1
fi

# Wipe existing partition table
sgdisk --zap-all "$DISK"

# Create partitions: 512M ESP + rest for Btrfs
sgdisk -n 1:0:+512M -t 1:EF00 "$DISK"
sgdisk -n 2:0:0 -t 2:8300 "$DISK"

# Wait for kernel to register partitions
udevadm settle

PART1="${DISK}-part1"
PART2="${DISK}-part2"

# Wait for partition devices to appear (NVMe can be async)
for part in "$PART1" "$PART2"; do
	for i in $(seq 10); do
		[ -e "$part" ] && break
		sleep 0.5
	done
	if [ ! -e "$part" ]; then
		echo "ERROR: Partition $part did not appear after 5 seconds"
		exit 1
	fi
done

# Format filesystems with labels
mkfs.vfat -F 32 -n BOOT "$PART1"
mkfs.btrfs -f -L caldera "$PART2"

# Create Btrfs subvolumes
mount "$PART2" /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@flake
umount /mnt

# Mount subvolumes at target paths
BTRFS_OPTS="compress=zstd:1,noatime,ssd,discard=async,space_cache=v2"
mount -o "subvol=@root,$BTRFS_OPTS" "$PART2" /mnt

mkdir -p /mnt/{nix,home,var/log,swap,config,boot}

mount -o "subvol=@nix,$BTRFS_OPTS" "$PART2" /mnt/nix
mount -o "subvol=@home,$BTRFS_OPTS" "$PART2" /mnt/home
mount -o "subvol=@log,$BTRFS_OPTS" "$PART2" /mnt/var/log
mount -o "subvol=@swap,noatime,ssd" "$PART2" /mnt/swap
mount -o "subvol=@flake,$BTRFS_OPTS" "$PART2" /mnt/config
mount "$PART1" /mnt/boot

# Create swapfile
btrfs filesystem mkswapfile --size 8G /mnt/swap/swapfile

echo ""
echo "Disk formatted and mounted."

# --- Step 3: Place configuration ---
echo "[3/4] Installing configuration..."
echo ""

# Copy flake source to @flake subvolume
rsync -rL --no-perms --no-owner --no-group "$FLAKE/" /mnt/config/

# Initialize git repo (as root — chown comes after to fix all ownership including .git/)
git -C /mnt/config init
git -C /mnt/config config user.name "AeonRemnant"
git -C /mnt/config config user.email "aeonremnant@github.com"
git -C /mnt/config remote add origin git@github.com:AeonRemnant/caldera.git
git -C /mnt/config branch -M main
git -C /mnt/config add -A
git -C /mnt/config commit -m "Initial install"
git -C /mnt/config config branch.main.remote origin
git -C /mnt/config config branch.main.merge refs/heads/main

# Fix ownership of everything including .git/
chown -R 1000:100 /mnt/config

# Verify
if [ ! -f /mnt/config/flake.nix ]; then
	echo "ERROR: Flake copy failed — flake.nix not found at /mnt/config"
	exit 1
fi

echo "Configuration installed at /config"

# Place sops age key if present on ISO
if [ -f /etc/caldera/age.key ]; then
	mkdir -p /mnt/var/lib/sops-nix
	cp /etc/caldera/age.key /mnt/var/lib/sops-nix/key.txt
	chmod 0600 /mnt/var/lib/sops-nix/key.txt
	echo "Sops age key installed."
fi

# Place SSH deploy key for private repo access
if [ -f /etc/caldera/aeon ] && [ -f /etc/caldera/aeon.pub ]; then
	SSH_DIR="/mnt/home/$TARGET_USER/.ssh"
	mkdir -p "$SSH_DIR"
	cp /etc/caldera/aeon "$SSH_DIR/aeon"
	cp /etc/caldera/aeon.pub "$SSH_DIR/aeon.pub"
	chmod 0700 "$SSH_DIR"
	chmod 0600 "$SSH_DIR/aeon"
	chmod 0644 "$SSH_DIR/aeon.pub"
	chown -R 1000:100 "$SSH_DIR"

	# Configure SSH to use this key for GitHub
	cat > "$SSH_DIR/config" <<-'SSHEOF'
	Host github.com
	    IdentityFile ~/.ssh/aeon
	    IdentitiesOnly yes
	SSHEOF
	chmod 0600 "$SSH_DIR/config"

	# Pre-populate GitHub's SSH host keys so first pull doesn't prompt
	ssh-keyscan -t ed25519,rsa github.com >> "$SSH_DIR/known_hosts" 2>/dev/null || \
	cat > "$SSH_DIR/known_hosts" <<-'HOSTEOF'
	github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
	github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YCZE1hFXbmzg6iaUoQLaDAZdwtN526mUK/FLjOYRVHLIvtDFy0A0zmVFjnsDTN+LqtHOPF4NZB/GRHII+JhVEnHOmXXqdB0Gw1GhYilSm0TOSF0SQKSHkqaym7VVKiYruYkLaBNoZaFlNP0kEJ5GZrJlEy7v0K6hSMOyqIKCqFg+T3AGXL5t0oUj5RfGdXsu8f9OgLCZTfXbnNqQJCANq0lEarMK0F+IDMT7K5BPiDABNPgWfbHFNSTLcDoqNMm6SOMdL8a/SzPFNLSwMisHAMeMMLjOBPA1HBvqj+B1tho5fB2nXKm8rgyU7AF/A56Rz5FW2pKoC0M=
	HOSTEOF
	chmod 0644 "$SSH_DIR/known_hosts"

	chown -R 1000:100 "$SSH_DIR"

	echo "SSH deploy key installed."
fi

# --- Step 4: Install NixOS ---
echo "[4/4] Installing NixOS..."
echo ""
echo "Copying pre-built system to disk (fully offline)..."
echo ""

nixos-install --system "$SYSTEM_CLOSURE" --no-root-passwd

# --- Done ---
echo ""
echo "========================================"
echo "  Installation complete!"
echo ""
echo "  Default user: operator"
echo "  Default password: 1142"
echo "  (change it immediately with: passwd)"
echo ""
echo "  Configuration: /config"
echo "  Rebuild: rebuild"
echo "  Upgrade: upgrade"
echo ""
echo "  Remove the USB and reboot."
echo "========================================"
