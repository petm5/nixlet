# NixOS Appliance Image Builder

This Nix module lets you build NixOS disk images aimed toward software appliances.

## Features

### Immutable

- Built on the Nix package manager and nixpkgs.
- The root filesystem is always mounted read-only
- User data is stored on a separate partition that can be erased to perform a factory reset.

### Monolithic

- New system images are fetched from an update server and handled automatically by `systemd-sysupdate`.
- Updates are applied atomically with an A/B scheme, allowing for easy rollbacks.

### Minimal

- The default config only includes packages required to run a basic system.

### Secure

- The base system comes with a minimal set of services.
- The user data partition can optionally be encrypted with LUKS.
- Support for secure boot and dm-verity is in progress.

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

## Notes

- Nixpkgs unstable is required for now due to the use of bleeding-edge features in various systemd components. NixOS 24.05 will probably work once released.
