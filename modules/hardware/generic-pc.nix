# Support some generic PC hardware
{

  boot.kernelModules = [
    "usb_storage" "uas" "sd_mod"
    "r8169"
    "ehci-hcd" "ehci-pci"
    "xhci-hcd" "xhci-pci" "xhci-pci-renesas"
    "nvme"
    "aesni_intel" "crypto_simd"
  ];

}
