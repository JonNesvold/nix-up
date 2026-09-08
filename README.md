<h1 align="center">Perseus 🛡️</h1>

<p align="center">
  <strong>Privacy-hardened NixOS for laptops that do engineering <em>and</em> gaming.</strong>
</p>

<p align="center">
  <a href="https://github.com/JonNesvold/perseus/actions/workflows/nix-up.yaml">
    <img src="https://github.com/JonNesvold/perseus/actions/workflows/nix-up.yaml/badge.svg" alt="CI"/>
  </a>
  <a href="https://github.com/JonNesvold/perseus/releases">
    <img src="https://img.shields.io/github/v/tag/JonNesvold/perseus" alt="Version"/>
  </a>
  <a href="https://github.com/JonNesvold/perseus/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/JonNesvold/perseus" alt="License"/>
  </a>
</p>

---

Built for laptops that double as workstations and gaming rigs. Default-deny networking, per-app Bubblewrap prisons, encrypted DNS with community-maintained blocklists, and custom Rust daemons for the gaps Wayland still leaves open. Everything driven from a single `user-config.nix`.

## Why Perseus

- **Default-deny network.** Every outbound connection is queued to OpenSnitch for per-app approval. DNS goes through local `dnscrypt-proxy` over DoH with OISD + HaGeZi blocklists merged daily.
- **Bubblewrap prisons, no Flatpak.** Every proprietary desktop app runs in a custom `bwrap` derivation with explicit filesystem, socket, and D-Bus scope. No runtime, fully declarative.
- **Custom Rust daemons** fill gaps the Wayland ecosystem still hasn't closed (see [System Architecture](#system-architecture)).
- **Niri + DankMaterialShell.** Scrollable-tiling Wayland with a real shell UI — widgets, launcher, notifications, media controls.
- **Gaming works.** NVIDIA Prime offloading, `gamescope`, `gamemode`, `mangohud`, Steam sandboxed with Proton and controller support.
- **One file to rule them all.** `user-config.nix` toggles GPU, VPN, dev languages, browsers. No spelunking through modules.

## Quickstart

> Requires NixOS Yarara (26.05) or later, ~20 GB free, on bare metal.

```bash
git clone https://github.com/JonNesvold/perseus
cd perseus
./nixup.sh                                # interactive wizard, writes user-config.nix
sudo nixos-install --flake .#<hostname>
sudo reboot
```

> **First boot:** set `hasGPU = false;` and `vpn = false;` in `user-config.nix`. Enable both after the system boots successfully.

`nixup.sh` also copies `/etc/nixos/hardware-configuration.nix` into `hosts/default/` and registers git clean filters so your hardware config, SSH keys, and personal `user-config.nix` are scrubbed from commits.

## System Architecture

Perseus runs on **Niri** (scrollable-tiling Wayland compositor) with **DankMaterialShell (DMS)** providing the shell UI — widgets, app launcher, media controls, notifications, system toggles, and the network menu. Touchpad gestures are handled natively by Niri.

To handle gaps in the Wayland ecosystem, Perseus ships custom Rust daemons:

- **`clammy`** — Wayland power and display management daemon. Hooks into D-Bus/logind and the `ext_idle_notify_v1` Wayland protocol to manage: gradual screen dimming before lock, lock screen activation, DPMS toggling, system suspend, lid switch handling, and external monitor awareness for clamshell mode. Also feeds dock state into PAM — fingerprint auth is skipped when the lid is closed on a dock (the reader is under the lid).

- **`ntl` / `ntl-daemon` (NastyTechLords)** — Security auditing tool and its notification daemon. A systemd timer runs the audit every 6 hours, inspecting processes, network state, filesystem integrity, privacy leaks, and (with `--full`) Nix store integrity. Reports land in `/var/log/nastyTechLords/`. Run `ntl report` for the latest summary, `ntl run` to audit now.

## Application Sandboxing

Every proprietary desktop app runs in a custom **Bubblewrap prison** — no Flatpak, no runtime, fully declarative Nix derivations:

- **Slack, Teams, Spotify, Edge, Logseq, Steam** — private mount/pid/ipc namespaces, isolated fake `$HOME` per app, Wayland-native rendering, GPU passthrough for calls and playback, memory caps via systemd scopes.
- **Filtered D-Bus, where it applies.** Slack, Spotify, Teams, and Steam each talk to a per-app `xdg-dbus-proxy` socket that whitelists portals (screenshare, notifications, MPRIS) and nothing else. Edge gets no host bus at all — it runs on a private `dbus-run-session`. Logseq is the exception: it binds the session bus read-only and unfiltered (see [Trade-offs](#threat-model--known-trade-offs)).
- **URL escape hatch.** Slack's jail contains an `xdg-open` shim that forwards links through the OpenURI portal to your real browser, so SSO sign-in flows round-trip correctly. A persistent per-app `/tmp` keeps Electron's single-instance socket alive across launches.
- **Teams' icon is the poop emoji.** Edge's is the vomit emoji. Iconography as threat modeling.
- **`jail-dev`** — throwaway containers for untrusted NPM/Node projects: no SSH agent, isolated filesystem, `.env` injection, jail indicator in the prompt.

## Privacy & Network Defense

The network stack is default-deny.

- **OpenSnitch + nftables**: All outbound traffic is queued to OpenSnitch for per-application approval. The nftables output chain explicitly allows only DNS (to local `dnscrypt-proxy`) and WireGuard/Tailscale (by fwmark) before queuing everything else to OpenSnitch **without** the `bypass` flag — if OpenSnitch crashes, DNS and VPN keep working but all other traffic is dropped.
- **Encrypted DNS**: `dnscrypt-proxy2` on `127.0.0.1:53` handles all DNS (Cloudflare/Quad9, DNSSEC required). Blocklist merged daily from **OISD big** + **HaGeZi** native vendor-telemetry lists (Windows/Office, Apple, TikTok, Samsung, LG webOS) + HaGeZi DoH/VPN-bypass list — ~350k domains, community-maintained, auto-updated. A partial download is discarded rather than applied.
- **Policy blackhole**: Deliberate policy blocks (AI coding assistants: Copilot, Tabnine, Codeium, Cursor, CodeWhisperer, JetBrains AI) plus app-telemetry endpoints not covered by community lists, pinned in `/etc/hosts`. Telemetry opt-out environment variables set system-wide.
- **VPN**: Native WireGuard integration for Mullvad, secrets encrypted via `sops-nix` and `age`. Tailscale coexists — a route reconciler keeps Mullvad from swallowing the tailnet, and Tailscale's DNS is disabled so nothing bypasses dnscrypt.
- **Network hardening**: MAC address randomization (Wi-Fi and Ethernet), disabled IP forwarding, SYN cookies, martian logging, ICMP echo disabled.
- **AppArmor**: Enabled with `killUnconfinedConfinables`.
- **No swap**: Both swap devices and zram are force-disabled to prevent memory dumps.
- **Least-privilege sudo**: Passwordless sudo is limited to three exact commands (reboot, VPN start, VPN stop).
- **SSH**: Disabled unless you supply a public key. When enabled, it listens on port 7889, key-only, no root login, with `fail2ban` in front.
- **Docked-aware PAM**: Fingerprint auth (lock screen, sudo, polkit) is skipped when docked with the lid closed — instant password fallback instead of a timeout on an unreachable reader.

## Browsers

**Firefox** provisioned with declarative policies.

- **Hardening**: **Betterfox** (`Fastfox.js`, `Peskyfox.js`, `Securefox.js`, `Smoothfox.js`) loaded via flake input into `extraConfig`. On top of that, declarative `settings.nix` locks down telemetry, disables Pocket, blocks fingerprinting, enforces HTTPS-only, disables WebRTC, and blocks DoH/DoT bypass. Firefox Studies and Normandy are disabled.
- **Data clearing**: cache, history, form data, downloads, and sessions are cleared on shutdown. Cookies and offline app data are deliberately **kept** — clearing them logs you out of everything on every reboot. Flip `privacy.clearOnShutdown.cookies` in `home/firefox/default.nix` if you want the stricter behaviour.
- **Theming**: **Catppuccin** `userChrome.css` loaded via flake input.
- **Extensions**: Force-installed and pinned — uBlock Origin (with curated filter lists), DarkReader, Firemonkey, SponsorBlock, Return YouTube Dislike, OneTab, 600% Sound Volume, FrankerFaceZ. All other extension installs are policy-blocked.

## Gaming

- **NVIDIA**: Prime offloading configured (`nvidia-drm.modeset=1`, early KMS).
- **Performance tooling**: `gamemode`, `gamescope`, `mangohud`.
- **Steam**: Bubblewrap-jailed with pressure-vessel/Proton compatibility, isolated Steam home, memory caps.
- **Controllers**: DualSense and generic gamepad support via `antimicrox` and system uinput access.

## Development Environment

- **Language stacks**: Python, Go, Rust, Node.js, and Android toggled via `user-config.nix`. Paths and environment variables merged dynamically.
- **Per-project isolation**: `direnv` with Nix integration — drop a `.envrc` in any project directory for automatic isolated environments.
- **Editor**: Neovim via `nixvim` — Catppuccin theme, Treesitter, Telescope, `conform.nvim`, and language-specific LSPs.
- **Containers**: Rootless Podman for daily use; dockerd available behind sudo (no docker group — it's root-equivalent).
- **Jailed frontend dev**: `jail-dev` launches a Bubblewrap container for untrusted Node/NPM work with restricted filesystem and no SSH agent.

## Project Structure

```
hosts/default/          # Machine-specific NixOS and hardware config
modules/
  apps/                 # Thunderbird
  dev/                  # Language tooling, nixvim
  hardware/             # clammy, NVIDIA, Thunderbolt
  security/             # Privacy, firewall, telemetry deny, VPN, SSH
  system/               # Niri, DMS, greetd, packages, environment
home/                   # Home-manager: Firefox, zsh
programs/               # Custom Rust daemons (clammy, ntl, ntl-daemon)
packages/               # Bubblewrap prisons + custom program derivations
configs/                # Dotfiles (Alacritty, GTK, Mullvad)
patches/                # Kernel patches
secrets/                # sops-encrypted VPN config
docs/                   # Module import graph (d2)
```

## Configuration

Everything toggleable lives in `user-config.nix`:

| Key                          | Type    | Effect                                               |
| ---------------------------- | ------- | ---------------------------------------------------- |
| `username`                   | string  | Login account name                                   |
| `hostname`                   | string  | Machine name and flake output (`.#<hostname>`)       |
| `gitName` / `gitEmail`       | string  | System-wide git identity                             |
| `isLaptop`                   | bool    | Enables clammy (idle/lock/suspend, docked-aware PAM) |
| `hasGPU`                     | bool    | NVIDIA drivers + Prime offloading                    |
| `intelBusId` / `nvidiaBusId` | string  | PCI bus IDs for Prime (required when `hasGPU`)       |
| `thunderbolt`                | bool    | Thunderbolt/dock support                             |
| `timezone`                   | string  | System timezone                                      |
| `latitude` / `longitude`     | float   | Location for blue-light filtering                    |
| `vpn`                        | bool    | Mullvad WireGuard + sops-nix secrets                 |
| `email`                      | bool    | Thunderbird                                          |
| `browsers`                   | list    | `"firefox"` (hardened), `"brave"` (plain package)    |
| `devTools`                   | list    | `"python"`, `"go"`, `"rust"`, `"node"`, `"android"`  |
| `extraHosts`                 | attrset | Custom `/etc/hosts` entries                          |
| `wallpaperPath`              | path    | Desktop wallpaper, relative to repo root             |
| `avatarPath`                 | path    | Login avatar, resized to 96×96 at build time         |

## VPN Setup (Optional)

Requires `vpn = true;` in `user-config.nix`.

```bash
mkdir -p ~/.config/sops/age
nix-shell -p age -c "age-keygen -o ~/.config/sops/age/keys.txt"
# Add the resulting public key to .sops.yaml
# Place your WireGuard config in secrets/wireguard.yaml under mullvad_conf
nix-shell -p sops -c "sops -e -i secrets/wireguard.yaml"
```

Toggle the tunnel at runtime with `mullvad-toggle`, or check state with `mullvad-status`.

## Maintenance

```bash
nix flake update                                    # Update inputs
sudo nixos-rebuild switch --flake .#<hostname>      # Rebuild
sudo nixos-rebuild switch --rollback                # Rollback
ntl report                                          # Latest security audit
ntl run                                             # Audit now
```

## Shipped

- ~~**Bubblewrap-only sandboxing.**~~ Done. Flatpak eliminated — every isolated app is a custom `bwrap` derivation.
- ~~**Community-maintained DNS blocklists.**~~ Done. OISD + HaGeZi merged daily into dnscrypt-proxy; hand-rolled hosts entries reduced to deliberate policy blocks.
- ~~**Least-privilege sudo.**~~ Done. NOPASSWD reduced from `ALL` to three exact commands.
- ~~**greetd + DMS greeter.**~~ Done. Replaced LightDM; fingerprint-aware, avatar support.
- ~~**sops-nix secrets.**~~ Done. WireGuard config encrypted at rest with an age key.

## Roadmap

- **Secure Boot via Lanzaboote.** Signed boot chain end-to-end, `sbctl`-managed keys, kernel and initrd verified before handoff.
- **Encrypted root + impermanence.** LUKS on root, wipe `/` on every boot, persist only what's explicitly declared.
- **Multi-host support.** Promote `hosts/default/` to a proper multi-host layout with shared modules and per-host overrides.
- **Auditable build provenance.** All flake inputs pinned in CI, `nix flake metadata` diffs surfaced on each release.
- **Reproducible install ISO.** A `nix build .#installer` target producing a custom ISO with `nixup.sh` baked in. Requires adding a `packages` output to the flake — not present yet.

### Paranoid Mode

Optional hardening for users with stricter threat models:

- **Hardware-backed secrets.** YubiKey or SoloKey for SSH auth, sudo, sops-nix age key, and LUKS unlock. Pull the token — secrets stop decrypting.

## Threat Model & Known Trade-offs

Honesty over marketing:

- **Steam's jail is the weakest.** pressure-vessel needs broad device and sysfs access; Proton runs a nested container inside the prison. It isolates your real `$HOME`, not much more.
- **Logseq's D-Bus is unfiltered.** Unlike the other prisons, Logseq binds the session bus directly. A compromised Logseq can enumerate and talk to anything on your session bus.
- **Prisons read `/etc` read-only.** Root-only secrets (shadow, WireGuard keys) are unreadable to the jailed uid regardless; world-readable config is visible.
- **OpenSnitch fail-closed is deliberate.** A crashed daemon drops all non-DNS/VPN traffic rather than failing open.
- **X11 is not fully gone.** Steam and some Electron GPU processes still ride xwayland-satellite.
- **The camera is IPU6.** Every `/dev/video*` node is raw Bayer; usable frames come from libcamera's software ISP via PipeWire. Image quality is mediocre and that is a driver-stack limitation, not a configuration one.
- **Firefox keeps cookies across reboots.** See [Browsers](#browsers).

## Acknowledgements

Built on the shoulders of [home-manager](https://github.com/nix-community/home-manager), [sops-nix](https://github.com/Mic92/sops-nix), [nixvim](https://github.com/nix-community/nixvim), [Niri](https://github.com/YaLTeR/niri), [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), [Betterfox](https://github.com/yokoffing/Betterfox), [OISD](https://oisd.nl), and [HaGeZi](https://github.com/hagezi/dns-blocklists).

## License

GPL-3.0
