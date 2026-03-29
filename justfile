# Caldera — NixOS system for the forge laptop

default:
    @just --list

# === Quality ===

# Run pre-commit checks
check:
    nix flake check

# Format all Nix files
fmt:
    nix fmt

# === Build ===

# Dry-build the system (verify it evaluates and builds)
verify:
    nix build .#nixosConfigurations.caldera.config.system.build.toplevel --dry-run

# === ISO ===

# Build the installer ISO
[group('iso')]
iso-build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building Caldera installer ISO..."
    nix build "path:$(pwd)#installer-iso"
    ISO=$(readlink -f result/iso/*.iso)
    SIZE=$(du -h "$ISO" | cut -f1)
    echo ""
    echo "ISO built: $ISO ($SIZE)"

# Flash ISO to a USB drive
[group('iso')]
iso-flash device:
    #!/usr/bin/env bash
    set -euo pipefail
    ISO=$(readlink -f result/iso/*.iso)
    if [ ! -f "$ISO" ]; then
        echo "ERROR: No ISO found. Run 'just iso-build' first."
        exit 1
    fi
    echo "Flashing $ISO to {{ device }}..."
    echo "WARNING: This will erase {{ device }}!"
    read -rp "Type YES to continue: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo "Aborted."
        exit 1
    fi
    sudo dd if="$ISO" of="{{ device }}" bs=4M status=progress oflag=sync
    echo "Done. Safe to remove USB."

# Boot installer ISO in a UEFI VM (AHCI disk, ~matches real hardware)
[group('iso')]
run:
    #!/usr/bin/env bash
    set -euo pipefail
    ISO=$(readlink -f result/iso/*.iso 2>/dev/null || true)
    if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
        echo "No ISO found. Run 'just iso-build' first."
        exit 1
    fi
    mkdir -p .vm
    OVMF=$(nix build --no-link --print-out-paths 'nixpkgs#OVMF.fd')/FV/OVMF.fd
    QEMU=$(nix build --no-link --print-out-paths 'nixpkgs#qemu')/bin/qemu-system-x86_64
    [ -f .vm/disk.qcow2 ] || \
        "$(dirname "$QEMU")/qemu-img" create -f qcow2 .vm/disk.qcow2 32G
    exec "$QEMU" \
        -enable-kvm \
        -m 4G \
        -smp 2 \
        -bios "$OVMF" \
        -cdrom "$ISO" \
        -device ahci,id=ahci \
        -drive file=.vm/disk.qcow2,format=qcow2,if=none,id=disk0 \
        -device ide-hd,drive=disk0,bus=ahci.0 \
        -nic user,model=virtio-net-pci \
        -boot d

# Remove built ISO and VM disk
[group('iso')]
iso-clean:
    rm -rf result .vm

# === Maintenance ===

# Garbage collect old generations
clean:
    sudo nix-collect-garbage -d
    nix-collect-garbage -d
