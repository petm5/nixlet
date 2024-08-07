{ super, ... }:

super.systemd.override {
  withAcl = false;
  withAnalyze = false;
  withApparmor = false;
  withAudit = false;
  withEfi = true;
  withCompression = false;
  withCoredump = false;
  withCryptsetup = false;
  withRepart = false;
  withDocumentation = false;
  withFido2 = false;
  withFirstboot = false;
  withHomed = false;
  withHostnamed = false;
  withHwdb = false;
  withImportd = false;
  withIptables = false;
  withKmod = false;
  withLibBPF = false;
  withLibidn2 = false;
  withLocaled = false;
  withLogind = false;
  withMachined = false;
  withNetworkd = false;
  withNss = false;
  withOomd = false;
  withPam = false;
  withPasswordQuality = false;
  withPCRE2 = false;
  withPolkit = false;
  withPortabled = false;
  withQrencode = false;
  withRemote = false;
  withResolved = false;
  withShellCompletions = false;
  withSysusers = false;
  withSysupdate = false;
  withTimedated = false;
  withTimesyncd = false;
  withTpm2Tss = false;
  withUkify = true;
  withUserDb = false;
  withUtmp = false;
  withVmspawn = false;
}
