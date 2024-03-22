{ config, lib, pkgs, ... }: {

  imports = [
    ./image/build-image.nix
  ];

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Use nftables
  networking.nftables.enable = true;
  boot.kernelModules = [
    "nf_tables"
    "nft_ct"
    "nft_log"
    "nf_log_syslog"
    "nft_fib"
    "nft_fib_inet"
    "nft_compat"
    "nfnetlink"
  ];

  # Replace sudo with doas
  security.sudo.enable = false;
  security.doas.enable = true;

  environment.systemPackages = with pkgs; [
    doas-sudo-shim
  ];

  networking.useNetworkd = true;
  systemd.network.wait-online.enable = false;

  systemd.watchdog = {
    runtimeTime = "10s";
    rebootTime = "30s";
  };

  virtualisation.vmVariant.config = {
    imports = [ ./profiles/debug.nix ];

    virtualisation.graphics = false;

    virtualisation.writableStore = false;

    virtualisation.qemu = {
      package = pkgs.qemu_test;
      guestAgent.enable = false;
    };
  };

}
