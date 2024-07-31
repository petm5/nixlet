{

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Use nftables
  networking.nftables.enable = true;

  # Use systemd-networkd
  networking.useNetworkd = true;
  systemd.network.wait-online.enable = false;

  # Bridge that connects VMs to the network
  networking.bridges."br0".interfaces = [ "en*" "vmtap-*" ];

  # Load required modules
  boot.kernelModules = [
    "ip_tables"
    "x_tables"
    "nf_tables"
    "nft_ct"
    "nft_log"
    "nf_log_syslog"
    "nft_fib"
    "nft_fib_inet"
    "nft_compat"
    "nft_nat"
    "nft_chain_nat"
    "nft_masq"
    "nfnetlink"
    "nf_conntrack"
    "nf_log_syslog"
    "nf_nat"
    "af_packet"
    "bridge"
    "tcp_bbr"
    "sch_fq_codel"
    "ipt_rpfilter"
    "ip6t_rpfilter"
    "sch_fq"
    "tun"
    "tap"
  ];

}
