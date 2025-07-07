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
    releaseVersion = nixpkgs.lib.strings.trim (builtins.readFile ./VERSION);
  in {
    nixosSystems.x86_64-linux.nixlet = nixpkgs.lib.nixosSystem {
      modules = [
        ./modules/nixlet/nixlet-image.nix
        ./modules/hardware/generic-pc.nix
        (nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          nixlet.updates.enable = true;
          nixlet.updates.updateUrl = "${updateUrl}";
          system.image.version = releaseVersion;
          system.image.id = "nixlet";
          system.stateVersion = "24.05";
        }
      ];
    };
    nixosSystems.x86_64-linux.nixlet-insecure = nixpkgs.lib.nixosSystem {
      modules = [
        ./modules/nixlet/nixlet-image.nix
        ./modules/hardware/generic-pc.nix
        (nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          nixlet.updates.enable = true;
          nixlet.updates.updateUrl = "${updateUrl}";
          system.image.version = releaseVersion;
          nixlet.encrypt = false;
          system.image.id = "nixlet-insecure";
          system.stateVersion = "24.05";
        }
      ];
    };
    packages.x86_64-linux.nixlet = self.nixosSystems.x86_64-linux.nixlet.config.system.build.updatePackage;
    packages.x86_64-linux.nixlet-insecure = self.nixosSystems.x86_64-linux.nixlet-insecure.config.system.build.updatePackage;
    checks.x86_64-linux = nixpkgs.lib.listToAttrs (map (test: nixpkgs.lib.nameValuePair "${test}" (import ./tests/${test}.nix {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit self;
    })) [ "integration" "system-update" ]);
    apps.x86_64-linux.nixlet-live-test = let
      testSystem = self.nixosSystems.x86_64-linux.nixlet-insecure;
      script = (import ./tests/common.nix rec {
        inherit self;
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        lib = pkgs.lib;
      }).makeInteractiveTest {
        image = "${testSystem.config.system.build.finalImage}/${testSystem.config.image.fileName}";
      };
    in {
      type = "app";
      program = toString script;
    };
    devShells.x86_64-linux.default = import ./shell.nix { inherit pkgs; };
  };
}
