{
  description = "A read-only server OS based on NixOS";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  };
  outputs = { self, nixpkgs }: {
    nixosModules.appliance = ./modules/appliance;
    nixosConfigurations.appliance = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.appliance
        ./profiles/server/configuration.nix
        {
          release = "1";
          updateUrl = "https://github.com/peter-marshall5/nixos-appliance/releases/latest/download/";
        }
      ];
    };
    packages.x86_64-linux.serverAppliance = self.nixosConfigurations.appliance.config.system.build.release;
    packages.x86_64-linux.default = self.packages.x86_64-linux.serverAppliance;
  };
}
