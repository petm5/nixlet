# nixlet

A minimal, immutable NixOS-based distro with automatic A/B updates.

- Currently intended for headless servers running Docker containers
- Supports a secure chain of trust using Secure Boot and dm-verity
- Supports automatic boot assessment and unattended rollbacks
- Supports automated provisioning of SSH authorized_keys
- Uses TPM-backed encryption for user data

## Included Software

- openssh
- podman

## Usage

Just write a release image (`nixlet_*.img`) to the system's disk and put your public SSH key in `default-ssh-authorized-keys.txt` on the first partition. The image is expanded on first boot.

The encrypted user data (home) partition is automatically unlocked via the TPM by default. A password or recovery key can be added via `systemd-cryptenroll`.

The default username is "admin" with password login disabled.

### SSH Key Provisioning

Authorized keys are provisioned on boot for the "admin" user if `.ssh/authorized_keys` doesn't exist. Keys are read from `default-ssh-authorized-keys.txt` on the ESP.

## Partition Layout

- ESP: vfat (96M)
- Verity A: dm-verity hash (64M)
- System A: erofs (512M)
- Verity B: dm-verity hash (64M)
- System B: erofs (512M)
- Home: btrfs on LUKS (Rest of available space)
