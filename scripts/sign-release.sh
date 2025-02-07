#! /usr/bin/env nix-shell
#! nix-shell -i bash -p efitools

set -eux

mkdir nixlet-signed
cp -L nixlet-unsigned/* nixlet-signed/

loopdev=$(sudo losetup -f)
sudo losetup -P "$loopdev" nixlet-signed/*.img
sudo mount "${loopdev}p1" /mnt -t vfat

sudo find nixlet-signed/ /mnt/ -name "*.efi" -type f -exec sbsign --key <(echo "$DB_KEY") --cert <(echo "$DB_CRT") --output {} {} \;

sudo mkdir -p /mnt/loader/keys/nixlet
sudo cp keys/*.auth /mnt/loader/keys/nixlet/

sudo umount /mnt
sudo losetup -d "$loopdev"

pushd nixlet-signed
sha256sum * > SHA256SUMS
popd
