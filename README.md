# Nix Hypervisor

An ultra-minimal image-based hypervisor OS with automatic A/B updates, based on NixOS.

## VM architecture

- VM instances are handled by QEMU and spawned by a systemd service
- VM storage is handled by LVM
- Each VM gets its own LV
- Configuration data for each VM is stored in a special LVM LV containing metadata files

## System versioning architecture

- System images are contained inside a single EFI capsule
- These can be stored on any filesystem supported by the firmware
- Version selection and rollbacks are handled by systemd-boot
- Updates are handled by systemd-sysupdate
