{ config, pkgs, lib, inputs, userConfig ? null, ... }:
let
  processedKing = pkgs.runCommand "king-processed.png" {
    buildInputs = [ pkgs.imagemagick ];
  } ''
    convert ${inputs.self}/${userConfig.avatarPath} \
      -gravity center -resize 96x96^ -extent 96x96 $out
  '' ;
  resolvConfForSandbox = pkgs.writeText "resolv.conf" ''
    nameserver 127.0.0.1
    nameserver ::1
  '' ;
in
{
  # Inject the resolv into the Nix build sandbox env
  nix.settings.extra-sandbox-paths = [
    "/etc/resolv.conf=${resolvConfForSandbox}"
  ];
  # ========================
  # BOOT CONFIGURATION
  # ========================
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 0;
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      # PCI Resource Allocation - Consolidated
      "pci=realloc"
      "pci=assign-busses"
      "pci=use_crs"
      "pcie_ports=native"
      # Thunderbolt Window Reservation (Critical for WD19TB)
      "pci=hpbussize=0x40"
      "pci=hpmemsize=2G"
      "pci=hpiosize=128M"
      # IOMMU/Thunderbolt Stability
      "intel_iommu=on"
      "iommu=pt"
      "split_lock_detect=warn"
      "bluetooth.disable_ertm=1"
      "snd_sof_intel_hda_common.all_components_lib=1"
    ];
    plymouth.enable = true;
    kernelModules = [ "hid-playstation" "uhid" "uinput" ];
  };
  # ========================
  # LOCALIZATION & TIME
  # ========================
  time.timeZone = userConfig.timezone;
  i18n = {
    supportedLocales = [ "en_US.UTF-8/UTF-8" "nb_NO.UTF-8/UTF-8" ];
    defaultLocale = "en_US.UTF-8";
  };
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };
  # ========================
  # SERVICES
  # ========================
  services = {
    fstrim = {
        enable = true;
        interval = "weekly";
    };
    tailscale = {
      enable = true;
      extraSetFlags = [ "--accept-dns=false" ];
    };
    dbus.enable = true;

    logind = {
      settings = {
        Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchDocked = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          IdleAction = "ignore";
        };
      };
    };

    # Power Management
    tlp = {
      enable = true;
      settings = {
        RESTORE_DEVICE_STATE_ON_STARTUP = 0;
        DEVICES_TO_DISABLE_ON_STARTUP = "";
        TLP_LID_SWITCH_AC = "ignore";
        TLP_LID_SWITCH_BAT = "ignore";
        WIFI_PWR_ON_AC = "on";
        WIFI_PWR_ON_BAT = "on";
        NATACPI_ENABLE = 1;
        TPACPI_ENABLE = 1;
        TPSMAPI_ENABLE = 1;
        USB_AUTOSUSPEND_ON_AC = "off";
        USB_AUTOSUSPEND_ON_BAT = "off";
        PCIE_ASPM_ON_AC = "powersave";

		# Empty = no PCIe runtime-PM denylist. Previously listed the Thunderbolt
        # controllers (0000:00:0d.2/0d.3) and the Nvidia GPU (01:00.0); dock has
        # been stable without them. Restore those IDs first if TB flakiness returns.
        RUNTIME_PM_DENYLIST = "";
      };
    };
    gnome.gnome-keyring.enable = true;
    # TLP is primary
    upower.enable = true;

    # Security
    opensnitch = {
      enable = true;
      settings = {
        LogLevel = 3;
      };
    };

    # Audio
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber.enable = true;
    };
    # Bluetooth
    blueman.enable = true;
    udev.extraRules = ''
    # PS5 DualSense controller over USB
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
    # PS5 DualSense Edge controller over USB
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0660", TAG+="uaccess"

    # Ensure uinput is accessible for Steam
    KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"

  '';
  };
  # ========================
  # USERS & SECURITY
  # ========================
  users.users.${userConfig.username} = {
    isNormalUser = true;
    uid = userConfig.uid;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "adbusers" ];  # "docker" removed
    shell = pkgs.zsh;
    packages = with pkgs; [ tree ];
    homeMode = "0751";
    # Home Manager Zsh conflict else
    ignoreShellProgramCheck = true;
  };
  security = {
    sudo.extraRules = [{
      users = [ userConfig.username ];
      commands = [
        { command = "/run/current-system/sw/bin/systemctl reboot";                options = [ "NOPASSWD" "NOSETENV" ]; }
        { command = "/run/current-system/sw/bin/systemctl start wg-quick-mullvad"; options = [ "NOPASSWD" "NOSETENV" ]; }
        { command = "/run/current-system/sw/bin/systemctl stop wg-quick-mullvad";  options = [ "NOPASSWD" "NOSETENV" ]; }
      ];
    }];
    rtkit.enable = true;
    polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "net.reactivated.fprint.device.enroll" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
        }
      });

      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.login1.suspend" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
        }
      });
    '';
  };

  # ========================
  # NETWORKING
  # ========================
  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = false;
      dispatcherScripts = [{
        type = "basic";
        source = pkgs.writeText "toggle-wifi" ''
          INTERFACE=$1
          ACTION=$2
          IFACE_TYPE=$(${pkgs.networkmanager}/bin/nmcli -g GENERAL.TYPE dev show "$INTERFACE" 2>/dev/null)
          if [ "$IFACE_TYPE" = "ethernet" ]; then
            if [ "$ACTION" = "up" ]; then
              ${pkgs.networkmanager}/bin/nmcli radio wifi off
            elif [ "$ACTION" = "down" ]; then
              ${pkgs.networkmanager}/bin/nmcli radio wifi on
            fi
          fi
        '';
      }];
    };
      #firewall = {
      #  allowedTCPPorts = [ 7775 443 ];
      #  allowedUDPPorts = [ 53 ];
      #  checkReversePath = "loose";
      #};
  };
  # ========================
  # ENVIRONMENT & VARIABLES
  # ========================
  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GTK_THEME = "Juno:dark";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "niri";
      XCURSOR_THEME = "Bibata-Modern-Amber";
      XCURSOR_SIZE = "24";
      GST_PLUGIN_PATH = "/run/current-system/sw/lib/gstreamer-1.0";
      PIPEWIRE_LATENCY = "256/48000";
      QT_LOGGING_RULES = "qt.svg.warning=false;qt.qpa.wayland.warning=false";

      # Forces Wayland compositors to prioritize the Nvidia GPU (card0) over Intel (card1)
      WLR_DRM_DEVICES = "/dev/dri/card0:/dev/dri/card1";
    };
    etc = {
      "boltd.conf".text = ''
        [Daemon]
        AuthorizationMode = automatic
      '';
      # Fusuma gesture configuration (replacing libinput-gestures)
      "fusuma/config.yml".text = ''
        swipe:
          3:
            left:
              command: "niri workspace next"
            right:
              command: "niri workspace prev"
          4:
            up:
              command: "rofi -show drun"
            down:
              command: "niri '[con_id=__focused__] scratchpad show' || niri 'workspace back_and_forth'"
            left:
              command: "niri workspace next"
            right:
              command: "niri workspace prev"
        pinch:
          2:
            in:
              command: "niri '[con_id=__focused__] fullscreen toggle'"
            out:
              command: "niri '[con_id=__focused__] floating toggle'"
        hold:
          4:
            command: "rofi -show window"
        threshold:
          swipe: 0.25
          pinch: 0.4
        interval:
          swipe: 0.8
          pinch: 0.1
      '';
      # for ssh agent
      "gnupg/scdaemon.conf".text = ''
        disable-ccid
      '';
      # Global GTK Dark Theme Configuration
      "gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=1
        gtk-theme-name=Juno
        gtk-icon-theme-name=Papirus-Dark
        gtk-font-name=MesloLGS NF 11
        gtk-cursor-theme-name=Bibata-Modern-Amber
        gtk-cursor-theme-size=24
      '';
      "gtk-3.0/gtk.css".text = ''
        @import url("${inputs.self}/configs/gtk-theme/gtk.css");
      '';
      "gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=1
        gtk-theme-name=Juno
        gtk-icon-theme-name=Papirus-Dark
        gtk-font-name=MesloLGS NF 11
        gtk-cursor-theme-name=Bibata-Modern-Amber
      '';
      "gtk-4.0/gtk.css".text = ''
        @import url("${inputs.self}/configs/gtk-theme/gtk.css");
      '';
      # User avatars
      "user-avatars/king-${userConfig.username}.png".source = processedKing;
      # Desktop Environment Configs - Wayland only
      "alacritty/alacritty.toml".source = "${inputs.self}/configs/alacritty-config/alacritty.toml";
    };
  };
  # ========================
  # NIX CONFIGURATION
  # ========================

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
      randomizedDelaySec = "14m";
    };
    settings = {
      auto-optimise-store = true;
      max-jobs = "auto";
      cores = 0;
    };
  };
  # ========================
  # HARDWARE
  # ========================
  powerManagement = lib.mkIf userConfig.isLaptop {
    enable = true;
  };
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experiment = true;
        };
      };
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    steam-hardware.enable = true;
    enableAllFirmware = true;
  };

  # ========================
  # VIRTUALIZATION
  # ========================
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  # networking.nftables.ruleset is applied declaratively, so a rebuild flushes
  # and reapplies the whole ruleset — taking Docker's nat and filter tables with
  # it. Docker does not notice and does not reinstall them until it restarts,
  # leaving containers with no masquerade and no route out.
  systemd.services.docker = {
    after = [ "nftables.service" ];
    partOf = [ "nftables.service" ];
  };
  virtualisation.podman.enable = true;   # no dockerCompat — docker binary already exists
  # ========================
  # PROGRAMS
  # ========================
  programs.git = {
    enable = true;
    config = {
      user.name = userConfig.gitName;
      user.email = userConfig.gitEmail;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ========================
  # SYSTEMD SERVICES
  # ========================
  systemd = {
    services.display-manager.serviceConfig = {
      Environment = [
        "XDG_DATA_DIRS=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "XDG_DATA_DIRS+=/run/current-system/sw/share"
        "GTK_DATA_PREFIX=/etc"
        "XDG_CONFIG_DIRS=/etc"
      ];
    };
    services.NetworkManager-wait-online.enable = false;

    # this is for clamshell action with clammy..
    tmpfiles.rules = [
      # Disable lid switch as wakeup source to prevent suspend loops
      "w /proc/acpi/wakeup - - - - LID0"
    ];
    services."systemd-rfkill@".enable = false;
    sockets.systemd-rfkill.enable = false;
  };

  systemd.user.services.opensnitch-ui = {
    description = "OpenSnitch UI";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.opensnitch-ui}/bin/opensnitch-ui";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # ========================
  # SYSTEM SCRIPTS
  # ========================
  system = {
    userActivationScripts = {
      king = ''
        cp ${config.environment.etc."user-avatars/king-${userConfig.username}.png".source} /home/${userConfig.username}/.face
        chmod 644 /home/${userConfig.username}/.face
      '';
    };
  };
  # ========================
  # XDG & FILE ASSOCIATIONS
  # ========================
  xdg.mime.defaultApplications = {
    # Nemo as default file manager
    "inode/directory" = "nemo.desktop";
    "application/x-gnome-saved-search" = "nemo.desktop";
    # OnlyOffice for all office formats
    "application/vnd.oasis.opendocument.text" = "onlyoffice-desktopeditors.desktop";
    "application/vnd.oasis.opendocument.spreadsheet" = "onlyoffice-desktopeditors.desktop";
    "application/vnd.oasis.opendocument.presentation" = "onlyoffice-desktopeditors.desktop";
    # OnlyOffice for MS Office formats
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "onlyoffice-desktopeditors.desktop";
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "onlyoffice-desktopeditors.desktop";
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "onlyoffice-desktopeditors.desktop";
    # Legacy MS Office formats
    "application/msword" = "onlyoffice-desktopeditors.desktop";
    "application/vnd.ms-excel" = "onlyoffice-desktopeditors.desktop";
    "application/vnd.ms-powerpoint" = "onlyoffice-desktopeditors.desktop";
    # PDF documents
    "application/pdf" = "org.pwmt.zathura.desktop";
  };
}
