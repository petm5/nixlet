{
  description = "Minimal image-based NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    baseUpdateUrl = "https://github.com/petm5/nixlet/releases/latest/download";
    relInfo = {
      system.image.id = "nixlet";
      system.image.version = "4.0.0";
    };
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
          boot.kernelParams = [ "quiet" ];
          system.image.updates.url = "${baseUpdateUrl}/nixlet";
        }
        self.nixosModules.image
        self.nixosModules.server
        relInfo
      ];
    }).config.system.build.updatePackage;
    packages.x86_64-linux.nixletNoTpm = (nixpkgs.lib.nixosSystem {
      modules = [
        ({ lib, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.05";
          system.image.encrypt = false;
        })
        {
          boot.kernelParams = [ "quiet" ];
          system.image.updates.url = "${baseUpdateUrl}/nixlet-no-tpm";
        }
        self.nixosModules.image
        self.nixosModules.server
        relInfo
      ];
    }).config.system.build.updatePackage;
    checks.x86_64-linux = nixpkgs.lib.listToAttrs (map (test: nixpkgs.lib.nameValuePair "${test}" (import ./tests/${test}.nix {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit self;
    })) [ "system-update" "ssh-preseed" "podman" ]);
  };
}
