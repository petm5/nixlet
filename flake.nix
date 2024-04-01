{
  description = "Minimal image-based operating system based on NixOS";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable-small;
  };
  outputs = { self, nixpkgs }: let
    baseUpdateUrl = "https://github.com/peter-marshall5/nixlet/releases/latest/download";
    relInfo = {
      version = "0.2";
    };
  in {
    nixosModules.nixlet = ./modules;
    nixosConfigurations.hypervisor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.nixlet
        ./modules/profiles/hypervisor.nix
        {
          system.image.id = "hypervisor";
          system.image.version = relInfo.version;
          ab-image.imageVariant.config.ab-image = {
            updates.url = "${baseUpdateUrl}";
          };
          system.stateVersion = "23.11";
        }
      ];
    };
    packages.x86_64-linux.hypervisor = self.nixosConfigurations.hypervisor.config.system.build.ab-image;
  };
}
