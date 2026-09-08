{ pkgs, lib, userConfig, config, ... }:
{
  networking.wireguard.enable = true;
  systemd.tmpfiles.rules = [
    "L+ /etc/wireguard/mullvad.conf 0600 root systemd-network - ${config.sops.secrets.mullvad-conf.path}"
  ];
  networking.wg-quick.interfaces.mullvad = {
    configFile = "/etc/wireguard/mullvad.conf";
    # postUp is NOT used here — wg-quick ignores it when configFile is set.
    # Routing rules live in ExecStartPost below, which always fires.
    autostart = true;
  };
  systemd.services.wg-quick-mullvad = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStartPost = let
      script = pkgs.writeShellScript "mullvad-post-up" ''
        ${pkgs.procps}/bin/sysctl -w net.ipv4.conf.all.src_valid_mark=1
      '';
    in [ "+${script}" ];
  };
  # Mullvad's wg-quick re-inserts a catch-all rule (not fwmark 0xca6c ->
  # lookup 51820) in the 5000-5100 range on every reconnect, swallowing
  # Tailscale's CGNAT range and the controller's advertised subnet into
  # table 51820 and black-holing them. A one-shot ExecStartPost can't keep
  # up — Mullvad re-inserts after it runs. This reconciler deletes any
  # Mullvad-inserted lookup 52 rule for our CIDRs at any priority other
  # than 100, then ensures ours exist at 100. Runs every 3s so a reconnect
  # re-insert is corrected within 3s.
  systemd.services.mullvad-route-fix = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = let
        script = pkgs.writeShellScript "mullvad-route-fix" ''
          # Mullvad's catch-all rule (not fwmark 0xca6c lookup 51820) drifts
          # across reconnects (seen at 44, 49) and shoves tailnet traffic into
          # the tunnel. We anchor tailnet CIDRs at priority 10 — below Mullvad's
          # floor (43) — pointing at table 52 (tailscale0-only). Purge any of our
          # CIDR rules NOT at 10, then ensure ours exist at 10.
          ${pkgs.iproute2}/bin/ip rule show \
            | ${pkgs.gnugrep}/bin/grep -E "to (100.64.0.0/10|192.0.0.0/24) lookup (52|main)" \
            | ${pkgs.gnugrep}/bin/grep -vE "lookup 52 .*priority 10( |$)" \
            | while read -r line; do
                prio=$(echo "$line" | ${pkgs.gnused}/bin/sed -n 's/.*priority \([0-9]*\).*/\1/p')
                dst=$(echo "$line" | ${pkgs.gnused}/bin/sed -n 's/.*to \([^ ]*\) .*/\1/p')
                tbl=$(echo "$line" | ${pkgs.gnused}/bin/sed -n 's/.*lookup \([a-z0-9]*\).*/\1/p')
                ${pkgs.iproute2}/bin/ip rule del to "$dst" lookup "$tbl" priority "$prio" 2>/dev/null || true
              done
          ${pkgs.iproute2}/bin/ip rule show | ${pkgs.gnugrep}/bin/grep -q "to 100.64.0.0/10 lookup 52 priority 10" \
            || ${pkgs.iproute2}/bin/ip rule add to 100.64.0.0/10 lookup 52 priority 10 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip rule show | ${pkgs.gnugrep}/bin/grep -q "to 192.0.0.0/24 lookup 52 priority 10" \
            || ${pkgs.iproute2}/bin/ip rule add to 192.0.0.0/24 lookup 52 priority 10 2>/dev/null || true
        '';
      in "+${script}";
    };
  };
  systemd.timers.mullvad-route-fix = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "3s";
    };
  };
  environment.systemPackages = with pkgs; [
    wireguard-tools
    (writeShellScriptBin "mullvad-toggle" ''
      if systemctl is-active --quiet wg-quick-mullvad; then
        sudo systemctl stop wg-quick-mullvad
        echo "VPN disconnected"
      else
        sudo systemctl start wg-quick-mullvad
        echo "VPN connected"
      fi
    '')
    (writeShellScriptBin "mullvad-status" ''
      if systemctl is-active --quiet wg-quick-mullvad; then
        echo "Connected"
      else
        echo "Disconnected"
      fi
    '')
  ];
}
