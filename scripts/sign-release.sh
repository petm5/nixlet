#! /usr/bin/env nix-shell
#! nix-shell -i bash -p efitools

set -eux

mkdir signed
cp -L result/* signed/

loopdev=$(sudo losetup -P -f signed/*.img)
sudo mount "${loopdev}p1" /mnt -t vfat

sudo find signed/ /mnt/ -name "*.efi" -type f -exec sbsign --key <(echo "$DB_KEY") --cert <(echo "$DB_CRT") --output {} {} \;

sudo mkdir -p /mnt/loader/keys/nixlet
sudo cp keys/*.auth /mnt/loader/keys/nixlet/

sudo umount /mnt
sudo losetup -d "$loopdev"
