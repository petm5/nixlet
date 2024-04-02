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
  boot.swraid.mdadmConf = ''
    PROGRAM echo
  '';
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

  environment.etc."libvirt-example/network.xml".text = ''
    <network>
      <name>host</name>
      <forward mode="bridge"/>
      <bridge name="virbr0"/>
    </network>
  '';

  environment.etc."libvirt-example/machine.xml".text = ''
    <domain type='kvm'>
      <name>test</name>
      <memory>64000</memory>
      <vcpu>2</vcpu>
      <os>
        <type>hvm</type>
        <bios useserial='yes'/>
      </os>
      <devices>
        <disk type='network' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source protocol="https" name="nixos-23.11/latest-nixos-minimal-x86_64-linux.iso">
            <host name="channels.nixos.org" port="443"/>
            <ssl verify="yes"/>
          </source>
          <target dev='hde' bus='scsi'/>
          <readonly/>
        </disk>
        <interface type='network'>
          <model type='virtio'/>
          <source network='host'/>
        </interface>
        <serial type='pty'>
          <source path='/dev/pts/1'/>
          <target port='0'/>
        </serial>
      </devices>
    </domain>
  '';

}
