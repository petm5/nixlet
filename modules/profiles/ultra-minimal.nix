{ config, lib, pkgs, modulesPath, ... }: {

  # Start out with a minimal system
  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  system.etc.overlay.mutable = false;
  users.mutableUsers = false;

  # Fix boot warning
  environment.etc."machine-id".text = " ";

  # Allow hostname change
  environment.etc.hostname.mode = "0600";

  # Don't include kernel or its modules in rootfs
  boot.kernel.enable = false;
  boot.modprobeConfig.enable = false;
  boot.bootspec.enable = false;
  system.build = { inherit (config.boot.kernelPackages) kernel; };
  system.modulesTree = [ config.boot.kernelPackages.kernel ] ++ config.boot.extraModulePackages;

  # Modules must be loaded by initrd
  boot.initrd.kernelModules = config.boot.kernelModules;

  services.openssh.startWhenNeeded = true;

  programs.nano.enable = false;

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
        rm -r $out/share/icons
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

    # Disable some unused systemd features
    systemd = super.systemd.override {
      withAcl = false;
      withApparmor = false;
      withEfi = false;
      withCryptsetup = false;
      withRepart = false;
      withDocumentation = false;
      withFido2 = false;
      withFirstboot = false;
      withHomed = false;
      withRemote = false;
      withShellCompletions = false;
      withTpm2Tss = false;
      withVmspawn = false;
    };

    # There's literally no reason to have multiple systemd packages in the system closure
    systemdMinimal = self.systemd;
    systemdLibs = self.systemd;

    systemdUkify = super.systemdMinimal.override {
      withEfi = true;
      withBootloader = true;
      withUkify = true;
    };

    util-linux = super.util-linux.override {
      ncursesSupport = false;
      nlsSupport = false;
    };

    openssh = super.openssh.overrideAttrs (final: prev: {
      doCheck = false;
      doInstallCheck = false;
      dontCheck = true;
    });

  })];

  boot.uki.settings.UKI.Stub = "${pkgs.systemdUkify}/lib/systemd/boot/efi/linux${pkgs.stdenv.hostPlatform.efiArch}.efi.stub";

}
