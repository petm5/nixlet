{
  description = "Minimal versioned operating system based on NixOS";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  };
  outputs = { self, nixpkgs }: let
    relInfo = {
      system.image.id = "hypervisor";
      system.image.version = "0.1";
      image.imageVariant.config.updateUrl = "https://github.com/peter-marshall5/nixos-appliance/releases/latest/download/";
      system.stateVersion = "23.11";
    };
  in {
    nixosModules.modules = ./modules;
    packages.x86_64-linux.hypervisor = (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.modules
        ./modules/profiles/hypervisor.nix
        ./modules/profiles/debug.nix
        relInfo
      ];
    }).config.system.build.image-release;
  };
}
