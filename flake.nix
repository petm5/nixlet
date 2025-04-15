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
    baseConfig = [
      ./modules/profiles/minimal.nix
      ./modules/profiles/image-based.nix
      ./modules/profiles/headless.nix
      ./modules/profiles/server.nix
      ./modules/hardware/generic-pc.nix
      (nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
      ./modules/image/repart-verity-store.nix
      ./modules/image/initrd-repart-expand.nix
      ./modules/image/sysupdate-verity-store.nix
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "24.05";
        system.image.updates.url = "${updateUrl}";
        system.image.id = "nixlet";
        system.image.version = releaseVersion;
      }
    ];
  in {
    packages.x86_64-linux.nixlet = (nixpkgs.lib.nixosSystem {
      modules = baseConfig;
    }).config.system.build.updatePackage;
    packages.x86_64-linux.nixlet-insecure = (nixpkgs.lib.nixosSystem {
      modules = baseConfig ++ [ {
        system.image.filesystems.encrypt = false;
        system.image.id = nixpkgs.lib.mkOverride 0 "nixlet-insecure";
      } ];
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
        image = "${self.packages.x86_64-linux.nixlet-insecure}/${self.packages.x86_64-linux.nixlet-insecure.combinedImage}";
      };
    in {
      type = "app";
      program = toString script;
    };
  };
}
