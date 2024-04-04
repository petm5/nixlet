# Nixlet

A minimal image-based NixOS builder with automatic A/B updates, made primarily for embedded situations.

## System profiles

- `hypervisor`: Intended for running VMs via qemu and libvirt. (~500MB)

Nixlet can be used as a library to generate your own image-based NixOS systems. See `flake.nix` for usage.

## Disk layout

| Name     | Contents                     |
| -------- | ---------------------------- |
| ESP      | Bootloader and kernel images |
| Root A/B | Read-only system images      |
| State    | User data                    |

The data partition is encrypted with LUKS. Support for secure boot signing and Nix store verification is in progress.

## Usage

Just flash a release `.img` file onto any drive. The image will expand itself on first boot. The default username and password is `nixos` and the default LUKS key is blank.

## Notes

- NixOS unstable is required for now due to the use of bleeding-edge features in various systemd components. NixOS 24.05 will probably work once released.
