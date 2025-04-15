#! /usr/bin/env nix-shell
#! nix-shell -i bash -p efitools

set -eux

mkdir nixlet-signed
cp -L nixlet-unsigned/* nixlet-signed/

loopdev=$(sudo losetup -f)
sudo losetup -P "$loopdev" nixlet-signed/*.img
sudo mount "${loopdev}p1" /mnt -t vfat

echo "$DB_KEY" > db.key
echo "$DB_CRT" > db.crt

sudo find nixlet-signed/ /mnt/ -name "*.efi" -type f -exec sbsign --key db.key --cert db.crt --output {} {} \;

sudo mkdir -p /mnt/loader/keys/nixlet
sudo cp keys/*.auth /mnt/loader/keys/nixlet/

sudo umount /mnt
sudo losetup -d "$loopdev"

pushd nixlet-signed
rm -f SHA256SUMS
sha256sum *.*[^img] > SHA256SUMS
popd
