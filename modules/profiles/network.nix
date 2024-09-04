{ lib, ... }: {

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Use nftables
  networking.nftables.enable = lib.mkDefault true;

  # Use systemd-networkd
  networking.useNetworkd = lib.mkDefault true;
  systemd.network.wait-online.enable = lib.mkDefault false;

  # Explicitly load networking modules
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
    "xt_conntrack"
    "nf_conntrack"
    "nf_log_syslog"
    "nf_nat"
    "af_packet"
    "bridge"
    "veth"
    "tcp_bbr"
    "sch_fq_codel"
    "ipt_rpfilter"
    "ip6t_rpfilter"
    "sch_fq"
    "tun"
    "tap"
    "xt_MASQUERADE"
    "xt_mark"
    "xt_comment"
    "xt_multiport"
    "xt_addrtype"
  ];

}
