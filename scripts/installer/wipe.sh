set -euo pipefail

echo "========================================"
echo "  Caldera Drive Wiper"
echo "========================================"
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
	echo "No drives found."
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

echo "Enter drive numbers to wipe (space-separated), or 'all':"
read -rp "> " SELECTION

TARGETS=()
if [ "$SELECTION" = "all" ]; then
	TARGETS=("${DISK_IDS[@]}")
else
	read -ra NUMS <<<"$SELECTION"
	for num in "${NUMS[@]}"; do
		idx=$((num - 1))
		if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#DISK_IDS[@]}" ]; then
			TARGETS+=("${DISK_IDS[$idx]}")
		else
			echo "Invalid selection: $num"
			exit 1
		fi
	done
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
	echo "No drives selected."
	exit 1
fi

echo ""
echo "WARNING: The following drives will be COMPLETELY ERASED:"
echo ""
for ID in "${TARGETS[@]}"; do
	DEV=$(readlink -f "/dev/disk/by-id/$ID")
	echo "  $ID"
	echo "    -> $DEV"
done
echo ""
read -rp "Type YES to wipe: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
	echo "Aborted."
	exit 1
fi

for ID in "${TARGETS[@]}"; do
	DEV=$(readlink -f "/dev/disk/by-id/$ID")
	echo ""
	echo "Wiping $DEV ($ID)..."

	# Unmount any mounted partitions from this drive
	mapfile -t PARTS < <(lsblk -lno NAME "$DEV" 2>/dev/null | tail -n +2 || true)
	for part in "${PARTS[@]}"; do
		[ -z "$part" ] && continue
		umount -f "/dev/$part" 2>/dev/null || true
	done
	umount -f "$DEV" 2>/dev/null || true

	# Wipe filesystem signatures on partitions first
	for part in "${PARTS[@]}"; do
		[ -z "$part" ] && continue
		wipefs -af "/dev/$part" 2>/dev/null || true
	done

	# Wipe filesystem signatures on the disk itself
	wipefs -af "$DEV"

	# Destroy GPT and MBR partition tables
	sgdisk --zap-all "$DEV"

	# TRIM/discard all SSD cells
	blkdiscard "$DEV" 2>/dev/null &&
		echo "  SSD TRIM complete." ||
		echo "  (blkdiscard not supported, skipping)"

	echo "  Wiped."
done

echo ""
echo "All selected drives wiped."
echo "Run caldera-install to partition and install."
