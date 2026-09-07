{pkgs, userConfig ? null, inputs, ... }:
let
  sandboxed-logseq = import ../../packages/sandboxed-logseq.nix { inherit pkgs userConfig; };
  sandboxed-frontend = pkgs.callPackage ../../packages/sandboxed-frontend.nix {};
  dms = inputs.dms.packages.${pkgs.system}.default;
  dgop = inputs.dgop.packages.${pkgs.system}.default;
  ntl-daemon = pkgs.callPackage ../../packages/ntl-daemon.nix {};
  sandboxed-steam = pkgs.callPackage ../../packages/sandboxed-steam.nix {};
  sandboxed-edge = pkgs.callPackage ../../packages/sandboxed-edge.nix {};
  sandboxed-spotify = pkgs.callPackage ../../packages/sandboxed-spotify.nix {};
  sandboxed-teams = pkgs.callPackage ../../packages/sandboxed-teams.nix {};
  sandboxed-slack = pkgs.callPackage ../../packages/sandboxed-slack.nix {};
in
{
  # Global software packages to install
  environment.systemPackages = with pkgs; [
    # Development tools
    curl
    git
    gcc
    openssl
    vscodium

    # System utilities
    dms
    dgop
    quickshell
    direnv
    btop
    jq
    fastfetch
    fzf
    ripgrep
    tmux
    ydotool
    pciutils
    usbutils
    iw
    bolt
    upower
    powertop
    v4l-utils
    libcamera
    networkmanagerapplet
    element-desktop
    remmina
    ntl-daemon
    evtest
    libinput

    # ipu6
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.icamerasrc-ipu6
    gst_all_1.gst-libav
    libcamera
    xdg-desktop-portal-gtk

    # File manager and themes
    nemo
    juno-theme

    # Desktop utilities
    brightnessctl
    playerctl
    pavucontrol
    gnupg
    libnotify
    mdcat
    xwayland-satellite

    # Wayland-specific tools
    wl-clipboard
    xdg-desktop-portal
    sweet # GTK theme

    # Network and Bluetooth GUI tools
    overskride # Modern Rust+GTK4 Bluetooth manager

    # Terminal emulator
    alacritty

    mpv

    # Gaming utilities
    gamemode
    gamescope
    mangohud
    antimicrox
    sandboxed-steam

    # music
    sandboxed-spotify

    # Network tools
    dig
    iftop
    nethogs

    # Encryption tools
    age
    sops

    # Screen Recording
    obs-studio
    wf-recorder

    # Secure communication
    signal-desktop
    element-desktop

    # microsoft communication (ugh -- not because its nice to have)
    sandboxed-teams

    # slack
    sandboxed-slack

    # Privacy and security tools
    dnscrypt-proxy
    opensnitch
    opensnitch-ui

    # Privacy utilities
    tor
    torsocks
    proxychains-ng

    # System security auditing tools
    lynis

    # Office and document tools
    rnote
    sandboxed-logseq
    onlyoffice-desktopeditors
    zathura
    evince
    tectonic

    # Bluetooth tools
    bluez
    bluez-tools

    # Zsh and theme
    zsh
    zsh-powerlevel10k
    zsh-syntax-highlighting

    # Fonts and cursors
    fira-code
    meslo-lgs-nf
    font-awesome_6
    dejavu_fonts
    liberation_ttf
    fira-code-symbols
    papirus-icon-theme
    bibata-cursors
    adwaita-icon-theme
    hicolor-icon-theme
    tela-icon-theme

    libayatana-appindicator
    android-tools

    # Never trust anything a frontend developer makes
    # Never trust Microsoft! 
    sandboxed-frontend
    sandboxed-edge

    # Pandoc and live MD rendering script
    pandoc
    wkhtmltopdf
    typst
    tinymist
    (pkgs.writeScriptBin "mdlive" ''
      #!/bin/bash
      FILE="$1"
      HTML="/tmp/$(basename "$FILE" .md).html"
      pandoc "$FILE" -s -o "$HTML"
      firefox "$HTML" &
      while inotifywait -e modify "$FILE"; do
        pandoc "$FILE" -s -o "$HTML"
      done
    '')
    inotify-tools
  ];

  # This registers the fonts with your system so applications can find them.
  fonts.packages = with pkgs; [
    fira-code
    meslo-lgs-nf
    font-awesome_6
    dejavu_fonts
    liberation_ttf
    fira-code-symbols
    # Additional icon fonts for better brand logos
    material-design-icons
    material-icons
    noto-fonts-color-emoji
    nerd-fonts.symbols-only # More comprehensive Nerd Fonts collection
    nerd-fonts.fira-code
    font-awesome_5
  ];
}
