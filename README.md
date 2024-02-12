# NixOS Appliance Image Builder

This Nix module lets you build NixOS disk images aimed toward software appliances.

## Disk layout

| Name     | Contents                     |
| -------- | ---------------------------- |
| ESP      | Bootloader and kernel images |
| Root A/B | Read-only system images      |
| Data     | User data                    |

The data partition can be encrypted with LUKS.

## Usage

This repo includes a reference server configuration intended for testing.

Here is an example `flake.nix` for a minimal system:

```nix
{
  description = "Example appliance image";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    nixos-appliance = {
      url = github:peter-marshall5/nixos-appliance;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixos-appliance }: {
    nixosConfigurations.appliance = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-appliance.nixosModules.appliance
        {
          release = "1"; # Should be a numeric version number
          updateUrl = "https://github.com/username/repo/releases/latest/download/";

          # Encryption is disabled by default.
          # diskImage.luks.enable = true;

          # Intended for testing only. Allows logging in as root for debugging.
          users.users.root.password = "password";

          system.stateVersion = "24.05";
        }
      ];
    };
    packages.x86_64-linux.default = self.nixosConfigurations.appliance.config.system.build.release;
  };
}
```

## Security

Support for secure boot and dm-verity is in progress.

## Notes

- Nixpkgs unstable is required for now due to the use of bleeding-edge features in various systemd components. NixOS 24.05 will probably work once released.
