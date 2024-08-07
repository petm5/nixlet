{ super, ... }:

super.openssh.overrideAttrs (final: prev: {
  doCheck = false;
  doInstallCheck = false;
  dontCheck = true;
})
