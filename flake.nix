{
  description = "Minimal image-based NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    updateUrl = "https://github.com/petm5/nixlet/releases/latest/download";
    releaseVersion = "0.1.4";
  in {
    nixosModules.server = {
      imports = [
        ./modules/profiles/server.nix
      ];
    };
    nixosModules.image = {
      imports = [
        ./modules
        ./modules/profiles/base.nix
        ./modules/image/disk
      ];
    };
    packages.x86_64-linux.nixlet = (nixpkgs.lib.nixosSystem {
      modules = [
        ({ lib, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.05";
        })
        {
          boot.kernelParams = [ "console=ttyS0" "systemd.journald.forward_to_console" ];
          system.image.updates.url = "${updateUrl}";
          system.image.id = "nixlet";
          system.image.version = releaseVersion;
        }
        self.nixosModules.image
        self.nixosModules.server
      ];
    }).config.system.build.updatePackage;
    checks.x86_64-linux = nixpkgs.lib.listToAttrs (map (test: nixpkgs.lib.nameValuePair "${test}" (import ./tests/${test}.nix {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit self;
    })) [ "system-update" "ssh-preseed" "podman" ]);
  };
}
