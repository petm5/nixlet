# nixlet

A minimal, immutable NixOS-based distro with automatic A/B updates.

- Intended for headless servers running Docker containers via podman
- Supports a secure chain of trust using Secure Boot and dm-verity
- Supports automatic boot assessment and unattended rollbacks
- Supports automated provisioning of SSH authorized_keys
- Uses TPM-backed encryption for user data

## Usage

Just write a release image (`nixlet_*.img`) to the system's disk.

Setup is handled by systemd-firstboot. You will be prompted to set up a root password. SSH keys and a root password can be passed as credentials via SMBIOS strings for automated provisioning.

The encrypted user data (home) partition is automatically unlocked via the TPM by default. A password or recovery key can be added via `systemd-cryptenroll`.

## Partition Layout

The disk is set up with a ChromeOS-style A/B scheme, containing two versions of the root filesystem.

- ESP: vfat (96M)
- Verity A: dm-verity hash (64M)
- System A: erofs (512M)
- Verity B: dm-verity hash (64M)
- System B: erofs (512M)
- Home: btrfs on LUKS (Rest of available space)
