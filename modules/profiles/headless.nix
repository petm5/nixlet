{ lib, ... }: {

  # We don't have a console, emergency mode doesn't make sense
  systemd.enableEmergencyMode = false;

  # Disable console on TTY
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;
  console.enable = false;

  # The system should reboot on failure
  systemd.watchdog = lib.mkDefault {
    runtimeTime = "10s";
    rebootTime = "30s";
  };

  boot.kernelParams = [
    "panic=1" "boot.panic_on_fail"
    "console=ttyS0" "console=tty0"
    "quiet"
  ];

  boot.loader.grub.splashImage = null;

}
