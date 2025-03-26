{ config, lib, pkgs, modulesPath, ... }: let

  inherit (pkgs.stdenv.hostPlatform) efiArch;

  verityImgAttrs = builtins.fromJSON (builtins.readFile "${config.system.build.intermediateImage}/repart-output.json");
  usrAttrs = builtins.elemAt verityImgAttrs 1;
  verityAttrs = builtins.elemAt verityImgAttrs 0;

  usrUuid = usrAttrs.uuid;
  verityUuid = verityAttrs.uuid;
  verityUsrHash = usrAttrs.roothash;

in {

  options.system.image = {
    compress = lib.mkEnableOption "image compression" // {
      default = true;
    };
    sshKeys = {
      enable = lib.mkEnableOption "provisioning of default SSH keys from ESP";
      keys = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        default = [];
      };
    };
  };

  imports = [
    (modulesPath + "/image/repart.nix")
  ];

  config = {

    assertions = [
      { assertion = config.boot.initrd.systemd.enable; }
    ];

    # systemd-gpt-auto-generator only supports auto-detection of root and usr partitions.
    # For partition auto-detection, We can put the Nix store contents in /usr, and then bind-mount /usr to /nix/store.

    boot.initrd = {
      systemd.dmVerity.enable = true;
      systemd.additionalUpstreamUnits = [ "initrd-usr-fs.target" ];
      supportedFilesystems.erofs = true;

      # Use stronger compression
      compressor = lib.mkDefault "zstd";
      compressorArgs = lib.mkDefault [ "-6" ];
    };

    boot.kernelParams = [ "mount.usrfstype=erofs" "mount.usrflags=ro" "usrhash=${config.system.build.verityUsrHash}" ];

    fileSystems."/nix/store" = {
      device = "/usr";
      options = [ "bind" ];
    };

    image.repart.partitions = {
      "10-esp" = {
        contents = {
          # Include systemd-boot
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

          # Include default SSH keys, used in tests
          "/default-ssh-authorized-keys.txt" = lib.mkIf config.system.image.sshKeys.enable {
            source = pkgs.writeText "ssh-keys" (lib.concatStringsSep "\n" config.system.image.sshKeys.keys);
          };
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "96M";
          SizeMaxBytes = "96M";
          SplitName = "-";
        };
      };
      "20-usr-verity-a" = {
        repartConfig = {
          Type = "usr-verity";
          Label = "verity-${config.system.image.version}";
          SizeMinBytes = "64M";
          SizeMaxBytes = "64M";
          Verity = "hash";
          VerityMatchKey = "usr";
          SplitName = "verity";
          ReadOnly = 1;
        };
      };
      "22-usr-a" = {
        storePaths = [ config.system.build.toplevel ];
        stripNixStorePrefix = true;
        repartConfig = {
          Type = "usr";
          Label = "usr-${config.system.image.version}";
          Format = "erofs";
          Minimize = "best";
          Verity = "data";
          VerityMatchKey = "usr";
          SplitName = "usr";
          ReadOnly = 1;
        };
      };
    };

    image.repart.mkfsOptions = lib.mkIf config.system.image.compress {
      erofs = [ "-zlz4hc,12" "-C1048576" "-Efragments,dedupe,ztailpacking" ];
    };

    system.build = {

      inherit verityUsrHash;

      intermediateImage = (config.system.build.image.override {
        compression.enable = false;
      }).overrideAttrs(self: super: {
        pname = "${super.pname}-intermediate";
        systemdRepartFlags = super.systemdRepartFlags ++ [ "--defer-partitions=esp" ];
      });

      finalImage = (config.system.build.image.override {
        createEmpty = false;
        split = true;
      }).overrideAttrs (self: super: {
        pname = "${super.pname}-final";

        # Insert the UKI which should contain the verity hash
        finalPartitions = lib.recursiveUpdate super.finalPartitions {
          "10-esp" = {
            contents = {
              "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
                "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
            };
          };
        };

        preBuild = ''
          cp -v ${config.system.build.intermediateImage}/${config.image.repart.imageFileBasename}.raw .
          chmod +w ${config.image.repart.imageFileBasename}.raw
        '';
      });

      updatePackage = let
        updateFiles = [
          {
            name = "${config.system.image.id}_${config.system.image.version}.efi";
            path = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          }
          {
            name = "${config.system.image.id}_${config.system.image.version}_${verityUuid}.verity";
            path = "${config.system.build.finalImage}/${config.image.repart.imageFileBasename}.verity.raw";
          }
          {
            name = "${config.system.image.id}_${config.system.image.version}_${usrUuid}.usr";
            path = "${config.system.build.finalImage}/${config.image.repart.imageFileBasename}.usr.raw";
          }
        ];
        createHash = { name, path }: lib.concatStringsSep "  " [ (builtins.hashFile "sha256" path) name ];
      in (pkgs.linkFarm "${config.system.build.image.pname}-update-package" (updateFiles ++ [
        {
          name = "${config.system.image.id}_${config.system.image.version}.img";
          path = "${config.system.build.finalImage}/${config.image.repart.imageFileBasename}.raw";
        }
        {
          name = "SHA256SUMS";
          path = pkgs.writeText "sha256sums.txt" (lib.concatLines (map createHash updateFiles));
        }
      ]))
      // {
        combinedImage = "${config.system.image.id}_${config.system.image.version}.img";
      };

    };

  };

}
