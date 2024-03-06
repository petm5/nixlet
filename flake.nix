{
  description = "Immutable Appliance Image builder for NixOS";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  };
  outputs = { self, nixpkgs }: let
    relInfo = {
      release = "1";
      updateUrl = "https://github.com/peter-marshall5/nixos-appliance/releases/latest/download/";
      system.stateVersion = "23.11";
    };
  in {
    nixosModules.appliance = ./modules/appliance.nix;
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.appliance
        ./modules/profiles/common.nix
        ./modules/profiles/server.nix
        relInfo
      ];
    };
    packages.x86_64-linux.server = self.nixosConfigurations.server.config.system.build.release;
  };
}
