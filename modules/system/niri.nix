{ pkgs, userConfig, inputs, ... }:

{
  programs.niri.enable = true;

  # Niri config in KDL format
  environment.etc."niri/config.kdl".text = ''
    // =====================
    // DMS INTEGRATION
    // =====================
    // Include DMS-managed configuration files
    include "dms/colors.kdl"
    include "dms/layout.kdl"
    include "dms/binds.kdl"

    // =====================
    // INPUT CONFIGURATION
    // =====================
    input {
        keyboard {
            xkb {
                layout "us,no"
                options "caps:escape,eurosign:e,grp:ctrl_space_toggle"
            }
        }

        touchpad {
            tap
            natural-scroll
            dwt
            click-method "clickfinger"
        }

        mouse {
            // accel-speed 0.0
        }
    }


    // =====================
    // LAYOUT CONFIGURATION
    // =====================
    layout {
        gaps 8

        // IMPORTANT: transparent for DMS overview wallpaper integration
        background-color "transparent"
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
            proportion 1.0
        }

        default-column-width { proportion 1.0; }

        focus-ring {
            width 2
            active-color "#CAD3F5"
            inactive-color "#5B6078"
        }

        border {
            off
        }
        struts {
          left 0
          right 0
          top 0
          bottom 0
      }
    }

    // =====================
    // LAYER RULES (DMS Integration)
    // =====================
    // Place quickshell wallpaper on overview
    layer-rule {
        match namespace="^quickshell$"
        place-within-backdrop true
    }

    // Place blurred wallpaper on overview (if blur enabled)
    layer-rule {
        match namespace="dms:blurwallpaper"
        place-within-backdrop true
    }

    // =====================
    // CURSOR CONFIGURATION
    // =====================
    cursor {
        xcursor-theme "Bibata-Modern-Amber"
        xcursor-size 18
        hide-after-inactive-ms 2000
        hide-when-typing true
    }

    // =====================
    // WINDOW RULES
    // =====================
    window-rule {
        // All windows get slight transparency when unfocused
        match is-active=false
        opacity 0.95
    }

    window-rule {
        // Floating windows class
        match app-id="floating"
        open-floating true
    }

    window-rule {
        match app-id=r#"firefox|librewolf"#
        open-maximized true
    }

    window-rule {
        geometry-corner-radius 10
        clip-to-geometry true
    }

    // Open DMS windows as floating by default
    window-rule {
        match app-id=r#"org.quickshell$"#
        open-floating true
    }

    // GNOME apps styling
    window-rule {
        match app-id=r#"^org\.gnome\."#
        draw-border-with-background false
        geometry-corner-radius 12
        clip-to-geometry true
    }

    // Terminal apps - no borders
    window-rule {
        match app-id=r#"^org\.wezfurlong\.wezterm$"#
        match app-id="Alacritty"
        match app-id="com.mitchellh.ghostty"
        match app-id="kitty"
        draw-border-with-background false
    }

    // logaseq
    window-rule {
        match app-id="logseq"
        open-on-workspace "strategy"
        open-maximized true
        opacity 0.95
    }


    // =====================
    // KEY BINDINGS
    // =====================
    binds {
        // ===== BASIC ACTIONS =====
        Mod+Return { spawn "alacritty"; }
        Mod+Shift+Q { close-window; }
        Mod+Shift+C { spawn "sh" "-c" "niri msg action reload-config"; }
        Mod+Shift+E { quit; }
        Mod+Shift+S { spawn "logseq"; }

        // ===== VPN =====
        Mod+Shift+V { spawn "mullvad-toggle"; }

        // ===== DMS APPLICATION LAUNCHERS =====
        Mod+Space hotkey-overlay-title="Application Launcher" {
            spawn "dms" "ipc" "call" "spotlight" "toggle";
        }
        Mod+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
        Mod+V hotkey-overlay-title="Clipboard Manager" {
            spawn "dms" "ipc" "call" "clipboard" "toggle";
        }
        Mod+Comma hotkey-overlay-title="Settings" {
            spawn "dms" "ipc" "call" "settings" "focusOrToggle";
        }
        Mod+N hotkey-overlay-title="Notification Center" {
            spawn "dms" "ipc" "call" "notifications" "toggle";
        }
        Mod+Y hotkey-overlay-title="Browse Wallpapers" {
            spawn "dms" "ipc" "call" "dankdash" "wallpaper";
        }

        // ===== OTHER APP LAUNCHERS =====
        Mod+B { spawn "firefox"; }
        Mod+C { spawn "slack"; }
        Mod+M { spawn "nemo"; }
        Mod+G { spawn "steam"; }

        // ===== FOCUS (neovim hjkl) =====
        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }

        // Arrow keys (keep as backup)
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down { focus-window-down; }
        Mod+Up { focus-window-up; }

        // ===== MOVE WINDOWS =====
        Mod+Shift+H { move-column-left; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+L { move-column-right; }

        // Arrow keys
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Down { move-window-down; }
        Mod+Shift+Up { move-window-up; }

        // ===== COLUMN MANAGEMENT =====
        Mod+Period { consume-window-into-column; }
        Mod+Slash { expel-window-from-column; }

        // ===== LAYOUT =====
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Shift+Space { toggle-window-floating; }
        Mod+Tab { switch-focus-between-floating-and-tiling; }

        // Column width presets
        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { spawn "sudo" "systemctl" "reboot"; }

        // ===== WORKSPACES =====
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+0 { focus-workspace 10; }

        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }
        Mod+Shift+0 { move-column-to-workspace 10; }

        // Workspace navigation
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+Shift+Page_Down { move-column-to-workspace-down; }
        Mod+Shift+Page_Up { move-column-to-workspace-up; }

        // ===== MONITORS =====
        Mod+Ctrl+Left { focus-monitor-left; }
        Mod+Ctrl+Right { focus-monitor-right; }
        Mod+Ctrl+Shift+Left { move-column-to-monitor-left; }
        Mod+Ctrl+Shift+Right { move-column-to-monitor-right; }

        // ===== MEDIA KEYS (via DMS) =====
        XF86AudioRaiseVolume allow-when-locked=true {
            spawn "dms" "ipc" "call" "audio" "increment" "3";
        }
        XF86AudioLowerVolume allow-when-locked=true {
            spawn "dms" "ipc" "call" "audio" "decrement" "3";
        }
        XF86AudioMute allow-when-locked=true {
            spawn "dms" "ipc" "call" "audio" "mute";
        }

        // ===== BRIGHTNESS (via DMS) =====
        XF86MonBrightnessUp allow-when-locked=true {
            spawn "dms" "ipc" "call" "brightness" "increment" "5" "";
        }
        XF86MonBrightnessDown allow-when-locked=true {
            spawn "dms" "ipc" "call" "brightness" "decrement" "5" "";
        }

        // ===== SCREENSHOTS =====
        Print { screenshot-screen; }
        Mod+Print { screenshot; }
        Mod+Shift+Print { screenshot-window; }

        // ===== LOCK SCREEN (DMS) =====
        Mod+Alt+L hotkey-overlay-title="Lock Screen" {
            spawn "dms" "ipc" "call" "lock" "lock";
        }

        // ===== POWER =====
        XF86PowerOff { quit; }
    }

    // =====================
    // AUTOSTART
    // =====================
    spawn-at-startup "dms" "run"
    spawn-at-startup "clammy-start-session"

    // Clipboard history (for DMS clipboard widget)
    spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store &"

    // Environment for portals
    environment {
        XDG_CURRENT_DESKTOP "niri"
        XDG_SESSION_TYPE "wayland"
        XDG_SESSION_DESKTOP "niri"
        QT_QPA_PLATFORM "wayland"
        ELECTRON_OZONE_PLATFORM_HINT "auto"
        QT_QPA_PLATFORMTHEME "gtk3"
    }

    // =====================
    // MISC
    // =====================
    prefer-no-csd

    screenshot-path "~/screenshot-%Y%m%d-%H%M%S.png"

    hotkey-overlay {
        skip-at-startup
    }
  '';

  # XDG portal configuration for niri
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-gnome ];
    config = {
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      };
    };
  };

  # Create DMS config directories and placeholder kdl files
  # These will be populated by DMS at runtime
  system.userActivationScripts.niri-dms-configs = ''
    mkdir -p ~/.config/niri/dms
    mkdir -p ~/.config/niri
    
    # Create placeholder kdl files if they don't exist
    # DMS will populate these with actual values
    touch ~/.config/niri/dms/colors.kdl
    touch ~/.config/niri/dms/layout.kdl
    touch ~/.config/niri/dms/binds.kdl
    
    # Symlink main config
    ln -sf /etc/niri/config.kdl ~/.config/niri/config.kdl
  '';
}
