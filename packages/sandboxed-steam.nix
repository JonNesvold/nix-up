{ pkgs, ... }:
let
  # Tools the Steam bootstrap/pressure-vessel needs inside the jail
  runtimeDependencies = with pkgs; [
    coreutils
    gnutar
    gzip
    xz
    dbus
    kmod
  ];
  steam-launcher = pkgs.writeShellScriptBin "steam" ''
    ISOLATION_DIR="$HOME/.local/share/app-isolation/steam"
    mkdir -p "$ISOLATION_DIR/.local/share/Steam/config"
    mkdir -p "$HOME/Downloads"
    # Disable browser hardware accel (black screen fix for xwayland)
    echo '"SteamClient" { "DisableBrowserHardwareAccel" "1" }' > "$ISOLATION_DIR/.local/share/Steam/config/steam_dev.cfg"
    # Fix NixOS 'unbound variable' crashes — wrapper uses 'set -u'
    LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:-}"
    STEAM_EXTRA_PROFILE="''${STEAM_EXTRA_PROFILE:-}"
    STEAM_RUNTIME="''${STEAM_RUNTIME:-1}"
    USER_ID=$(id -u)
    XDG_RT="/run/user/$USER_ID"
    WAYLAND_SOCK="''${WAYLAND_DISPLAY:-wayland-1}"
    X_DISPLAY="''${DISPLAY:-:0}"
    HOST_BUS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RT/bus}"
    JAIL_PATH="${pkgs.lib.makeBinPath runtimeDependencies}:/run/current-system/sw/bin"

    # Filtered session bus. pressure-vessel hard-binds $XDG_RUNTIME_DIR/bus inside
    # the jail; with no socket there its inner bwrap aborts and no UI ever starts.
    PROXY_SOCK="$XDG_RT/steam-bus-proxy"
    SYNC_FIFO="$XDG_RT/steam-bus-proxy.sync"
    rm -f "$PROXY_SOCK" "$SYNC_FIFO"
    mkfifo -m 600 "$SYNC_FIFO"

    # --filter denies every name; --log prints each denied call, so the log tells
    # you which --talk= to add when a Steam feature misbehaves.
    ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
      --fd=3 \
      "$HOST_BUS" \
      "$PROXY_SOCK" \
      --filter \
      --log \
      3>"$SYNC_FIFO" &
    PROXY_PID=$!
    trap 'kill "$PROXY_PID" 2>/dev/null; rm -f "$PROXY_SOCK" "$SYNC_FIFO"' EXIT

    # Blocks until the proxy is listening — no sleep, no race.
    exec 9<"$SYNC_FIFO"
    rm -f "$SYNC_FIFO"
    if ! read -r -N 1 -u 9; then
      echo "steam: xdg-dbus-proxy exited before it was ready (bus: $HOST_BUS)" >&2
      exit 1
    fi

    ${pkgs.systemd}/bin/systemd-run \
      --user --scope --collect \
	  --unit=sandboxed-steam-$(date +%s) \
      --description="Sandboxed Steam" \
      -p MemoryMax=22G \
      ${pkgs.bubblewrap}/bin/bwrap \
        --unshare-all \
        --share-net \
        --die-with-parent \
        --new-session \
        --hostname "workstation" \
        --proc /proc \
        --dev-bind /dev /dev \
        --tmpfs /dev/shm \
        --tmpfs /tmp \
        --bind-try /tmp/.X11-unix /tmp/.X11-unix \
        --ro-bind /sys /sys \
        --ro-bind /nix /nix \
        --ro-bind /run/current-system /run/current-system \
        --ro-bind /run/opengl-driver /run/opengl-driver \
        --ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32 \
        --ro-bind /etc/fonts /etc/fonts \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --ro-bind /etc/machine-id /etc/machine-id \
        --ro-bind /etc/passwd /etc/passwd \
        --ro-bind /etc/group /etc/group \
        --ro-bind /etc/hosts /etc/hosts \
        --ro-bind-try /etc/localtime /etc/localtime \
        --ro-bind "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" /etc/ssl/certs/ca-certificates.crt \
        --bind "$ISOLATION_DIR" "$HOME" \
        --bind "$HOME/Downloads" "$HOME/Downloads" \
        --dir "$XDG_RT" \
        --bind "$PROXY_SOCK" "$XDG_RT/bus" \
        --bind-try "$XDG_RT/$WAYLAND_SOCK" "$XDG_RT/$WAYLAND_SOCK" \
        --bind-try "$XDG_RT/pipewire-0" "$XDG_RT/pipewire-0" \
        --bind-try "$XDG_RT/pulse" "$XDG_RT/pulse" \
        --setenv HOME "$HOME" \
        --setenv PATH "$JAIL_PATH" \
        --setenv XDG_RUNTIME_DIR "$XDG_RT" \
        --setenv WAYLAND_DISPLAY "$WAYLAND_SOCK" \
        --setenv DISPLAY "$X_DISPLAY" \
        --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RT/bus" \
        --setenv PULSE_SERVER "unix:$XDG_RT/pulse/native" \
        --setenv LD_LIBRARY_PATH "$LD_LIBRARY_PATH" \
        --setenv STEAM_EXTRA_PROFILE "$STEAM_EXTRA_PROFILE" \
        --setenv STEAM_RUNTIME "$STEAM_RUNTIME" \
        --setenv NIXOS_OZONE_WL "1" \
        --setenv STEAMWEBHELPER_ARGS "--disable-gpu" \
        --setenv STEAM_DISABLE_BROWSER_HARDWARE_ACCEL "1" \
        --setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
        ${pkgs.steam}/bin/steam \
          -cef-disable-gpu-compositing \
          -console \
          "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "sandboxed-steam-wayland";
  version = "2.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${pkgs.steam}/share/icons $out/share/icons
    cp ${steam-launcher}/bin/steam $out/bin/steam
    chmod +x $out/bin/steam
    cat > $out/share/applications/steam.desktop << EOF
[Desktop Entry]
Type=Application
Name=Steam (Sandboxed)
Exec=$out/bin/steam %u
Icon=steam
Terminal=false
Categories=Game;Network;
StartupWMClass=Steam
EOF
  '';
}
