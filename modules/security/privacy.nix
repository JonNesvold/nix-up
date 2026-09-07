{ lib, pkgs, ... }:
let
  StateDirName = "dnscrypt-proxy";
  StatePath = "/var/lib/${StateDirName}";
in
{
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:53" "[::1]:53" ];
      server_names = [ "cloudflare" "quad9-doh-ip4-port443-nofilter-pri" ];
      blocked_names.blocked_names_file = "${StatePath}/blocklist.txt";

      sources.public-resolvers = {
        urls = [ "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md" ];
        cache_file = "${StatePath}/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
      };
      require_dnssec = true;
      require_nolog = true;
      require_nofilter = false;
      timeout = 2500;
      keepalive = 30;
      ipv6_servers = true;
      block_ipv6 = false;
    };
  };

  systemd.services.dnscrypt-proxy2.serviceConfig.StateDirectory = StateDirName;

  systemd.tmpfiles.rules = [
      "f /var/lib/dnscrypt-proxy/blocklist.txt 0644 root root -"
  ];
  
  systemd.services.dnscrypt-blocklist-update = {
    description = "Update dnscrypt-proxy OISD blocklist";
    after = [ "network-online.target" "dnscrypt-proxy2.service" ];
    wants = [ "network-online.target" "dnscrypt-proxy2.service" ];
    path = with pkgs; [ curl coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "update-blocklist" ''
        BLOCKLIST_DIR="/var/lib/dnscrypt-proxy"
        BLOCKLIST_FILE="$BLOCKLIST_DIR/blocklist.txt"
        BLOCKLIST_TMP="$BLOCKLIST_FILE.tmp"

        mkdir -p "$BLOCKLIST_DIR"

        SOURCES=(
          "https://big.oisd.nl/domainswild"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.winoffice-onlydomains.txt"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.apple-onlydomains.txt"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.tiktok-onlydomains.txt"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.lgwebos-onlydomains.txt"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/native.samsung-onlydomains.txt"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/doh-vpn-proxy-bypass-onlydomains.txt"
        )

        : > "$BLOCKLIST_TMP"
        FAILED=0
        for url in "''${SOURCES[@]}"; do
          if ! curl -fsSL --max-time 60 "$url" >> "$BLOCKLIST_TMP"; then
            echo "FAILED: $url"
            FAILED=1
          fi
        done

        # Only replace if every source downloaded — partial list is worse than stale list
        if [ "$FAILED" -eq 0 ]; then
          sort -u "$BLOCKLIST_TMP" > "$BLOCKLIST_FILE"
          rm -f "$BLOCKLIST_TMP"
          systemctl restart dnscrypt-proxy2 || true
        else
          rm -f "$BLOCKLIST_TMP"
        fi
      '';
    };
  };

  systemd.timers.dnscrypt-blocklist-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "24h";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };

  networking = {
    nameservers = [ "127.0.0.1" "::1" ];
    nftables.enable = true;
    networkmanager = {
      dns = "none";

      settings = {
        connection = {
          "wifi.cloned-mac-address" = "random";
          "ethernet.cloned-mac-address" = "random";
        };
        device = {
          "wifi.scan-rand-mac-address" = "yes";
        };
      };
    };

    firewall = {
      enable = false;
      allowPing = false;
      logReversePathDrops = true;
    };
    nftables.ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;

          # Allow established/related connections
          ct state established,related accept
          ct state invalid drop

          # Loopback
          iifname "lo" accept

          # SSH
          tcp dport 7889 accept

          # Allow DNS responses to dnscrypt-proxy (localhost only)
          udp sport 53 iifname "lo" accept

          # ICMP for basic connectivity (optional, remove if paranoid)
          meta l4proto { icmp, icmpv6 } accept

          # OpenSnitch interception for inbound
          udp sport 53 queue flags bypass to 0
        }

        chain output {
          type filter hook output priority filter; policy drop;

          # Allow established/related
          ct state established,related accept

          # Loopback always allowed
          oifname "lo" accept

          # --- INFRASTRUCTURE ALLOWLIST (survives OpenSnitch crash) ---
          # DNS to local dnscrypt-proxy
          udp dport 53 ip daddr 127.0.0.1 accept
          udp dport 53 ip6 daddr ::1 accept

          # WireGuard tunnel
          oifname "mullvad" accept
          meta mark 0xca6c accept comment "WireGuard fwmark"
          meta mark & 0xff0000 == 0x80000 accept comment "Tailscale fwmark"

          # ICMP
          meta l4proto { icmp, icmpv6 } accept

          # --- OPENSNITCH QUEUE (no bypass = drop if dead) ---
          meta l4proto != tcp queue to 0
          tcp flags & (fin | syn | rst | ack) == syn queue to 0
        }

        chain opensnitch {}
      }

      table inet mangle {
        chain output {
          type route hook output priority mangle; policy accept;
        }
      }
    '';
  };

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "24h";
    bantime-increment.enable = true;

    jails.sshd = lib.mkForce ''
      enabled = true
      port = 7889
      filter = sshd
      maxretry = 3
    '';
  };

  environment.variables = {
    POWERSHELL_TELEMETRY_OPTOUT = "1";
    HOMEBREW_NO_ANALYTICS = "1";
    GATSBY_TELEMETRY_DISABLED = "1";
    FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT = "1";
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_all" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
  };

  services = {
    avahi.enable = false;
    geoclue2.enable = false;
    printing.browsing = false;
  };

  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
  };

  swapDevices = lib.mkForce [ ];
  zramSwap.enable = false;
}
