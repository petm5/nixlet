{
  description = "Minimal image-based operating system based on NixOS";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  };
  outputs = { self, nixpkgs }: let
    baseUpdateUrl = "https://github.com/peter-marshall5/nixlet/releases/latest/download";
    relInfo = {
      version = self.ref or "dirty";
      uuid = (import ./uuid.nix) (self.rev or self.dirtyRev);
    };
  in {
    nixosModules.nixlet = ./modules;
    packages.x86_64-linux.hypervisor = (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.nixlet
        ./modules/profiles/hypervisor.nix
        ./modules/profiles/debug.nix
        {
          system.image.id = "nixlet-hypervisor";
          system.image.version = relInfo.version;
          ab-image.imageVariant.config.ab-image = {
            updates.url = "${baseUpdateUrl}/hypervisor/";
            uuid = relInfo.uuid;
          };
          system.stateVersion = "23.11";
        }
      ];
    }).config.system.build.ab-image;
  };
}
