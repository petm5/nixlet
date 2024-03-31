{

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "usb-storage" "uas"
    "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "virtio_balloon" "virtio_console"
  ];

  boot.kernelModules = [
    "r8169"
  ];

  boot.kernelParams = [
    "nomodeset"
  ];

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
  '';

  security.doas.wheelNeedsPassword = false;

  services.openssh.enable = true;

}
