{
  description = "Minimal image-based NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  };
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    updateUrl = "https://github.com/petm5/nixlet/releases/latest/download";
    releaseVersion = "0.1.5";
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
          system.image.updates.url = "${updateUrl}";
          system.image.id = "nixlet";
          system.image.version = releaseVersion;
        }
        self.nixosModules.image
        self.nixosModules.server
      ];
    }).config.system.build.updatePackage;
    packages.x86_64-linux.nixlet-insecure = (nixpkgs.lib.nixosSystem {
      modules = [
        ({ lib, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.05";
        })
        {
          system.image.updates.url = "${updateUrl}";
          system.image.id = "nixlet-insecure";
          system.image.version = releaseVersion;
          system.image.filesystems.encrypt = false;
        }
        self.nixosModules.image
        self.nixosModules.server
      ];
    }).config.system.build.updatePackage;
    checks.x86_64-linux = nixpkgs.lib.listToAttrs (map (test: nixpkgs.lib.nameValuePair "${test}" (import ./tests/${test}.nix {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit self;
    })) [ "integration" "system-update" ]);
    apps.x86_64-linux.nixlet-live-test = let
      script = (import ./tests/common.nix rec {
        inherit self;
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        lib = pkgs.lib;
      }).makeInteractiveTest {
        image = self.packages.x86_64-linux.nixlet-insecure.diskImage;
      };
    in {
      type = "app";
      program = toString script;
    };
  };
}
