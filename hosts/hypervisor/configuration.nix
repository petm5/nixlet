{

  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./hypervisor.nix
    ../../modules
    # ./debug.nix
  ];

  networking.hostName = "hypervisor";
  system.image.id = "hypervisor";

  # Add a default user
  users.users."nixos" = {
    isSystemUser = true;
    initialPassword = "nixos";
    useDefaultShell = true;
    group = "nixos";
    extraGroups = [ "wheel" ];
  };
  users.groups.nixos = {};

  # Minimal VM testing
  # virtualisation.vmVariant.config = {
  #   boot.kernel.enable = lib.mkForce true;
  #   virtualisation = {
  #     qemu = {
  #       guestAgent.enable = false;
  #       package = pkgs.qemu_test;
  #     };
  #     diskImage = null;
  #     graphics = false;
  #   };
  # };  

  system.stateVersion = "23.11";

}
