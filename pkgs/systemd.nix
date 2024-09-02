{ super, ... }:

super.systemd.override {
  withAcl = false;
  withApparmor = false;
  withDocumentation = false;
  withRemote = false;
  withShellCompletions = false;
  withVmspawn = false;
}
