{ pkgs, ... }: let
  qemu = pkgs.qemu_test;
in {

  imports = [ ./server.nix ];

  virtualisation.libvirtd = {
    enable = true;
    package = pkgs.libvirt.override {
      enableZfs = false;
    };
    qemu.package = qemu;
    qemu.ovmf.enable = false;
  };

  # Support disk arrays
  boot.initrd.services.lvm.enable = true;
  boot.swraid.enable = true;
  boot.initrd.kernelModules = [ "raid0" "raid1" ];

  # Bridge for VM networking
  boot.kernelModules = [ "bridge" ];

  systemd.network.netdevs = {
    "10-bridge" = {
      netdevConfig = {
        Name = "virbr0";
        Kind = "bridge";
      };
    };
  };

  systemd.network.networks = {
    "10-bridge-uplink" = {
      name = "eth* en*";
      bridge = [ "virbr0" ];
    };
    "10-bridge-lan" = {
      name = "virbr0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

}
