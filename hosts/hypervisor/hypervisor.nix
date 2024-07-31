{ config, pkgs, ... }: let
  qemu = pkgs.qemu_tiny;
in {

  # Support disk arrays
  services.lvm.enable = true;
  environment.etc."lvm/lvm.conf".text = ''
    backup {
      archive = 0
      backup = 0
    }
  '';
  boot.swraid.enable = true;
  boot.swraid.mdadmConf = ''
    PROGRAM echo
  '';
  boot.initrd.kernelModules = [ "raid0" "raid1" ];

  boot.initrd.availableKernelModules = [ "kvm_intel" "kvm_amd" ];

  # VM service template
  systemd.services."qemu-vm@" = let
    script = pkgs.writeScript "qemu-vm-launch" ''
      #!${pkgs.runtimeShell}
      set -xeu

      lv="$1"
      vg="vms"
      disk="/dev/$vg/$lv"

      [ -e "$disk" ] || exit 1

      # Decode VM metadata from the LV name
      name=$(echo "$lv" | cut -d'-' -f1)
      mem=$(echo "$lv" | cut -d'-' -f2)
      cpus=$(echo "$lv" | cut -d'-' -f3)
      macaddr=$(echo "$lv" | cut -d'-' -f4 | sed 's/_/-/g')
      tapname="vmtap-''${name:0:10}"

      ${pkgs.iproute2}/bin/ip tuntap add dev "$tapname" mode tap
      ${pkgs.iproute2}/bin/ip link set "$tapname" up
      ${pkgs.iproute2}/bin/ip link set "$tapname" master br0

      onexit() {
        ${pkgs.iproute2}/bin/ip link set "$tapname" nomaster
        ${pkgs.iproute2}/bin/ip link set "$tapname" down
        ${pkgs.iproute2}/bin/ip link delete "$tapname"
        exit 0
      }

      trap onexit EXIT

      ${qemu}/bin/qemu-kvm \
        -m "$mem" \
        -drive file="$disk",if=virtio,format=raw \
        -netdev tap,id=net0,ifname="$tapname",script=no,downscript=no \
        -device virtio-net-pci,netdev=net0,romfile= \
        -cpu host \
        -smp "$cpus" \
        -nographic \
        -vga none \
        -bios ${qemu}/share/qemu/OVMF.fd
    '';
  in {
    serviceConfig = {
      ExecStartPre = [
      ];
      ExecStart = "${script} %i";
      ExecStop = [
      ];
    };
  };

  systemd.services."start-vms" = {
    script = ''
      vg="vms"

      for v in /dev/$vg/*; do
        ${config.systemd.package}/bin/systemctl start "qemu-vm@$(basename "$v")"
      done
    '';
    wantedBy = [ "default.target" ];
    requires = [ "network.target" ];
    after = [ "network.target" ];
  };

}
