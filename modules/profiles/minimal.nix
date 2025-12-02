{ config, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  boot.kernelModules = [
    # Required for systemd SMBIOS credential import
    "dmi_sysfs"
  ];

  # Remove foreign language support
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Use nftables
  networking.nftables.enable = true;

  # Use systemd-networkd
  networking.useNetworkd = true;
  systemd.network.wait-online.enable = true;

  programs.nano.enable = false;

}
