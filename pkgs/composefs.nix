{ super, ... }:

super.composefs.overrideAttrs (final: prev: {
  doCheck = false;
})
