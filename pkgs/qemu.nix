{ super, ... }:

(super.qemu_test.override {
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
})
