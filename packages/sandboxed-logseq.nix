{ pkgs, userConfig, ... }:
let
  pname = "logseq";
  version = "0.10.15";
  src = pkgs.fetchurl {
    url = "https://github.com/logseq/logseq/releases/download/${version}/Logseq-linux-x64-${version}.AppImage";
    sha256 = "1l95gcr89hdv0wk6xv25vh3zcqcq78mrrz6ly1z2rmlnyi9114cb"; 
  };
  isolationPath = "/home/${userConfig.username}/.local/share/app-isolation/logseq";
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  
  extraPkgs = pkgs: with pkgs; [ 
    libglvnd libxshmfence libxkbcommon wayland libGL vulkan-loader nvidia-vaapi-driver
    dconf 
  ];

  extraInstallCommands = ''
    mv $out/bin/${pname} $out/bin/${pname}-unwrapped
    
    cat > $out/bin/${pname} <<EOF
#!/bin/sh
mkdir -p "${isolationPath}"
exec ${pkgs.bubblewrap}/bin/bwrap \
  --unshare-all \
  --share-net \
  --dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --dir /dev/shm \
  --ro-bind /nix /nix \
  --ro-bind /etc /etc \
  --ro-bind /run/dbus /run/dbus \
  --ro-bind /run/opengl-driver /run/opengl-driver \
  --ro-bind-try /run/user/\$(id -u)/bus /run/user/\$(id -u)/bus \
  --ro-bind-try /run/user/\$(id -u)/at-spi /run/user/\$(id -u)/at-spi \
  --bind-try /run/user/\$(id -u)/wayland-0 /run/user/\$(id -u)/wayland-0 \
  --bind-try /run/user/\$(id -u)/wayland-1 /run/user/\$(id -u)/wayland-1 \
  --bind "${isolationPath}" "/home/${userConfig.username}" \
  --setenv HOME "/home/${userConfig.username}" \
  --setenv XDG_RUNTIME_DIR "/run/user/\$(id -u)" \
  --setenv WAYLAND_DISPLAY "\$WAYLAND_DISPLAY" \
  --setenv NVD_BACKEND direct \
  $out/bin/${pname}-unwrapped \
    --ozone-platform=wayland \
    --enable-wayland-ime \
    --wayland-text-input-version=3 \
    --enable-features=WaylandWindowDecorations
EOF
    chmod +x $out/bin/${pname}
  '';
}
