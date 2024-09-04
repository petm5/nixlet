{
  description = "Minimal image-based NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
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
    nixosConfigurations.release = nixpkgs.lib.nixosSystem {
      modules = [
        ({ lib, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          users.allowNoPasswordLogin = true;
          system.stateVersion = "24.05";
          system.image.id = "nixos-image";
          system.image.version = "1";
        })
        {
          boot.kernelParams = [ "quiet" "console=tty0" "console=ttyS0,115200n8" ];
        }
        self.nixosModules.image
        self.nixosModules.server
      ];
    };
    packages.x86_64-linux.releaseImage = self.nixosConfigurations.release.config.system.build.image;
    checks."x86_64-linux".system-update = (import ./tests/system-update.nix {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit self;
    });
  };
}
