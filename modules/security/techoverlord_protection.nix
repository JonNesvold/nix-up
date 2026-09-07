{ pkgs, userConfig, config, ... }:
let
  nastyTechLords = pkgs.callPackage ../../packages/ntl.nix {};

  ntlCli = pkgs.writeShellScriptBin "ntl" ''
    #!/usr/bin/env bash

    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    BINARY="${nastyTechLords}/bin/nasty-tech-lords"
    LOG_DIR="/var/log/nastyTechLords"

    show_help() {
        echo -e "''${GREEN}NastyTechLords Security Monitor (Rust Edition)''${NC}"
        echo -e "Protection against the tech overlords! 🛡️\n"
        echo -e "''${YELLOW}Usage:''${NC} ntl [command]"
        echo ""
        echo -e "''${YELLOW}Commands:''${NC}"
        echo -e "  ''${BLUE}run''${NC}              Run security audit now"
        echo -e "  ''${BLUE}run --full''${NC}       Run with deep inspection (Nix store)"
        echo -e "  ''${BLUE}status''${NC}           Show daemon status"
        echo -e "  ''${BLUE}report''${NC}           View latest audit summary"
        echo -e "  ''${BLUE}logs''${NC}             Follow live system logs"
        echo -e "  ''${BLUE}tray''${NC}             Output JSON for system tray"
        echo ""
    }

    case "$1" in
        run)
            echo -e "''${GREEN}󰒘 Starting NastyTechLords Audit...''${NC}"
            if [ "$2" = "--full" ]; then
                sudo $BINARY --full --verbose
            else
                sudo $BINARY --verbose
            fi
            ;;
        status)
            echo -e "''${GREEN}Daemon Status:''${NC}"
            sudo systemctl status nastyTechLords.timer --no-pager
            ;;
        report)
            if [ -f "$LOG_DIR/latest-summary.txt" ]; then
                cat "$LOG_DIR/latest-summary.txt"
            else
                LATEST=$(ls -t $LOG_DIR/audit-*.log 2>/dev/null | head -1)
                if [ -n "$LATEST" ]; then
                    cat "$LATEST"
                else
                    echo "No reports found."
                fi
            fi
            ;;
        logs)
            sudo journalctl -u nastyTechLords -f
            ;;
        tray)
            # JSON output for system tray integration
            if ! systemctl is-active --quiet nastyTechLords.timer; then
                echo '{"icon": "󰦞", "status": "inactive"}'
                exit 0
            fi
            if [ ! -f "$LOG_DIR/latest-summary.txt" ]; then
                echo '{"icon": "󰔟", "status": "pending"}'
                exit 0
            fi
			CRITICAL=$(grep -c "^\[CRITICAL\]" "$LOG_DIR/latest-summary.txt" 2>/dev/null)
            WARNING=$(grep -c "^\[WARNING\]" "$LOG_DIR/latest-summary.txt" 2>/dev/null)
            if [ "$CRITICAL" -gt 0 ]; then
                echo "{\"icon\": \"󰀦\", \"status\": \"critical\", \"critical\": $CRITICAL, \"warning\": $WARNING}"
            elif [ "$WARNING" -gt 0 ]; then
                echo "{\"icon\": \"󰀪\", \"status\": \"warning\", \"critical\": 0, \"warning\": $WARNING}"
            else
                echo '{"icon": "󰒘", "status": "ok", "critical": 0, "warning": 0}'
            fi
            ;;
        *)
            show_help
            ;;
    esac
  '';
  uid = toString config.users.users.${userConfig.username}.uid;
in
{

  environment.systemPackages = [
    nastyTechLords
    ntlCli
    pkgs.alacritty
    pkgs.libnotify
  ];

  systemd.services.nastyTechLords = {
    description = "NastyTechLords Security Audit Daemon";
    serviceConfig = {
		Type = "oneshot";
        ExecStart = "${nastyTechLords}/bin/nasty-tech-lords";
        SuccessExitStatus = [ 2 ];
        
        StandardOutput = "journal";
        StandardError = "journal";

        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        User = "root"; 

        ReadWritePaths = [ "/var/log/nastyTechLords" ];
        Environment = [
             "DISPLAY=:0"
             "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
        ];
    };
  };

  systemd.timers.nastyTechLords = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "6h";
        RandomizedDelaySec = "30min";
        Persistent = true;
    };
  };

  systemd.tmpfiles.rules = [
      "d /var/log/nastyTechLords 0750 root wheel -"
  ];

  users.users.${userConfig.username}.extraGroups = [ "wheel" ];

  systemd.user.services.ntl-daemon = {
    description = "NTL Security Monitor Daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = [
      ntlCli
      pkgs.alacritty
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.callPackage ../../packages/ntl-daemon.nix {}}/bin/ntl-daemon";
      Restart = "always";
      RestartSec = 5;
      Environment = [ "RUST_LOG=info" "NTL_POLL_INTERVAL=28800" ];
    };
  };
}
