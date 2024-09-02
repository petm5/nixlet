{
  description = "Minimal image-based NixOS configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
  in {
    nixosModules.server = {
      imports = [
        ./modules/profiles/server.nix
      ];
    };
    nixosModules.image = {
      imports = [
        ./modules
        ./modules/profiles/base.nix
        ./modules/image/disk
      ];
    };
    nixosConfigurations.release = nixpkgs.lib.nixosSystem {
      modules = [
        ({ lib, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          users.allowNoPasswordLogin = true;
          system.stateVersion = "24.05";
          system.image.id = "nixos-image";
          system.image.version = "1";
        })
        {
          boot.kernelParams = [ "quiet" "console=tty0" "console=ttyS0,115200n8" ];
        }
        self.nixosModules.image
        self.nixosModules.server
      ];
    };
    nixosConfigurations.test = nixpkgs.lib.nixosSystem {
      modules = [
        ({ lib, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          users.allowNoPasswordLogin = true;
          system.stateVersion = lib.versions.majorMinor lib.version;
          system.image.id = "nixos-image";
          system.image.version = "1";
        })
        ({ lib, ... }: {
          boot.kernelParams = [ "console=ttyS0,115200n8" "systemd.journald.forward_to_console=0" ];
          image.repart.mkfsOptions.squashfs = lib.mkForce [ "-comp zstd" "-Xcompression-level 2" "-b 64K" ];
          boot.initrd.compressor = lib.mkForce "zstd";
          boot.initrd.compressorArgs = lib.mkForce [ "-2" ];
          users.users."root" = {
            initialPassword = "nixos";
          };
        })
        # (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
        self.nixosModules.image
        self.nixosModules.server
      ];
    };
    packages.x86_64-linux.releaseImage = self.nixosConfigurations.release.config.system.build.image;
    packages.x86_64-linux.testImage = self.nixosConfigurations.test.config.system.build.image;
    apps.x86_64-linux.vm-test = let
      runner = pkgs.writeScript "run" ''
        cat ${self.packages.x86_64-linux.testImage}/*.raw > /var/tmp/test.img
        fallocate -l 2G /var/tmp/test.img
        mkdir /tmp/emulated_tpm
        ${pkgs.swtpm}/bin/swtpm socket --tpmstate dir=/tmp/emulated_tpm --ctrl type=unixio,path=/tmp/emulated_tpm/swtpm-sock --tpm2 &
        ${pkgs.qemu_kvm}/bin/qemu-kvm \
          -m 512M \
          -drive if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware} \
          -drive if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables} \
          -drive if=virtio,format=raw,file=/var/tmp/test.img,media=disk \
          -chardev socket,id=chrtpm,path=/tmp/emulated_tpm/swtpm-sock \
          -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
          -nic user,model=virtio,hostfwd=tcp:127.0.0.1:2200-:22 \
          -nographic
      '';
    in {
      type = "app";
      program = "${runner}";
    };
    # Broken for now since the disk must be writable
    # checks."x86_64-linux".uefi-boot = (import ./tests/uefi-boot.nix {
    #   pkgs = nixpkgs.legacyPackages."x86_64-linux";
    #   inherit self;
    # });
  };
}
