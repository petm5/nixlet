{
  description = "Minimal hypervisor based on NixOS";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-24.05;
  };
  outputs = { self, nixpkgs }: let
    baseUpdateUrl = "https://github.com/3xfc/nixlet/releases/latest/download";
    relInfo = {
      version = "0.3.0";
    };
  in {
    nixosConfigurations.hypervisor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/hypervisor/configuration.nix
        {
          system.image.version = relInfo.version;
          appliance.applianceVariant.config.appliance = {
            updates.url = "${baseUpdateUrl}";
          };
        }
      ];
    };
    packages.x86_64-linux.hypervisor = self.nixosConfigurations.hypervisor.config.system.build.ab-image;
  };
}
