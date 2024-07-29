{ config, pkgs, ... }: let
  qemu = pkgs.qemu_tiny;
in {

  # Support disk arrays
  boot.initrd.services.lvm.enable = true;
  boot.swraid.enable = true;
  boot.swraid.mdadmConf = ''
    PROGRAM echo
  '';
  boot.initrd.kernelModules = [ "raid0" "raid1" ];

  boot.initrd.availableKernelModules = [ "kvm_intel" "kvm_amd" ];

  # VM service template
  systemd.services."qemu-vm@" = let
    script = pkgs.writeScriptBin "qemu-vm-launch" ''
      #!${pkgs.runtimeShell}
      lv="$1"
      vg="vms"
      disk="/dev/$vg/$lv"

      [ -e "$disk" ] || exit 1

      # Decode VM metadata from the LV name
      name=$(echo "$lv" | cut -d'.' -f1)
      mem=$(echo "$lv" | cut -d'.' -f2)
      cpus=$(echo "$lv" | cut -d'.' -f3)
      macaddr=$(echo "$lv" | cut -d'.' -f4)

      echo "Starting VM $name"
      exec ${qemu}/bin/qemu-kvm \
        -m "$mem" \
        -drive file="$disk",if=virtio \
        -nic bridge,br=br0,model=virtio,mac="$macaddr" \
        -cpu host-passthrough \
        -smp "$cpus" \
        -nographic \
        -vga none
    '';
  in {
    serviceConfig.ExecStart = "${script} %i";
  };

  systemd.services."start-vms" = {
    script = ''
      vg="vms"

      for v in /dev/$vg/*; do
        ${config.systemd.package}/bin/systemctl start "qemu-vm@$(basename "$v")"
      done
    '';
    wantedBy = [ "default.target" ];
    requires = [ "lvm.service" ];
    after = [ "lvm.service" ];
  };

}
