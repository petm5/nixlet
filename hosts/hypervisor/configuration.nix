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
  users.users."admin" = {
    isSystemUser = true;
    useDefaultShell = true;
    group = "admin";
    extraGroups = [ "wheel" ];
    initialHashedPassword = "$y$j9T$3sdkKywE9OTrU5Fcb0fKP1$0CJE91AceNSQfjxl3kLBOam6hvMnpEI/yk7BSaS4699";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjg1Y1b2YyhoC73I4is0/NRmVb3FeRmpLf2Yk8adrxq petms@peter-pc"
    ];
  };
  users.groups.admin = {};

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
