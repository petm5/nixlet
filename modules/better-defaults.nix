{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  # Use latest kernel
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.kernelParams = [ "quiet" "console=tty0" "console=ttyS0,115200n8" ];
  boot.consoleLogLevel = lib.mkDefault 1;

  boot.tmp.useTmpfs = true;

  # Replace sudo with doas
  security.sudo.enable = lib.mkDefault false;
  security.doas.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    (lib.mkIf config.security.doas.enable doas-sudo-shim)
  ];

  services.openssh.settings.PasswordAuthentication = lib.mkDefault false;

  systemd.watchdog = lib.mkDefault {
    runtimeTime = "10s";
    rebootTime = "30s";
  };

  boot.initrd.systemd.enable = lib.mkDefault true;
  networking.useNetworkd = lib.mkDefault true;

  zramSwap.enable = true;
  boot.kernelModules = [ "zram" ];

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  nixpkgs.overlays = [(self: super: {

    # Ultra-minimal QEMU
    qemu_tiny = (super.qemu_test.override {
      enableDocs = false;
      capstoneSupport = false;
      guestAgentSupport = false;
      tpmSupport = false;
      libiscsiSupport = false;
      usbredirSupport = false;
      canokeySupport = false;
      hostCpuTargets = [ "x86_64-softmmu" ];
    }).overrideDerivation (old: {
      postFixup = ''
        cp "${pkgs.OVMF.fd + "/FV/OVMF.fd"}" $out/share/qemu/
      '';
      configureFlags = old.configureFlags ++ [
        "--disable-tcg"
        "--disable-tcg-interpreter"
        "--disable-docs"
        "--disable-install-blobs"
        "--disable-slirp"
        "--disable-virtfs"
        "--disable-virtfs-proxy-helper"
        "--disable-vhost-user-blk-server"
        "--without-default-features"
        "--enable-kvm"
        "--disable-tools"
      ];
    });

  })];

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

}
