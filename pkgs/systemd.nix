{ super, ... }:

super.systemd.override {
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
}
