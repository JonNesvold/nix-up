# Contributing to Perseus

Thanks for your interest in making Perseus better. This guide covers what's wanted, what isn't, and how to get a change merged.

## 🎯 Current Priority Areas

Suggestions, not assignments. Open an issue before starting anything large.

### High Priority

1. **Secure Boot via Lanzaboote**
   - Signed boot chain, `sbctl`-managed keys
   - Kernel and initrd verified before handoff
   - Must not break the existing `pci-of-null-subordinate` kernel patch

2. **Encrypted root + impermanence**
   - LUKS on root, `/` wiped on every boot
   - Persist only what's explicitly declared
   - `disko` is already a flake input but currently unused — this is where it earns its place

3. **Multi-host support**
   - Promote `hosts/default/` to a real multi-host layout
   - Shared modules, per-host overrides
   - Must not break the single-host quickstart

4. **NastyTechLords improvements**
   - Better NixOS-specific checks
   - Integration with `vulnix` for CVE scanning
   - Reduce false positives — the current process scanner flags any shell holding a non-unix socket, which is noisy enough to drown real findings

5. **Backup**
   - Borg or restic, declarative schedule
   - One-command restore

### Medium Priority

- Multi-monitor layout persistence
- More language modules (C++, Haskell, Zig)
- Better LSP and debugging configuration

### Nice to Have

- Custom Perseus ISO (`nix build .#installer` — needs a `packages` flake output first)
- Light/dark theme switching
- Smoother onboarding for non-power-users

## 📋 Contribution Guidelines

### Code Standards

1. **Nix indentation**: 2 spaces. A handful of files still use tabs; they're being converted, don't add more.
2. **Rust**: `rustfmt` defaults.
3. **Formatting**: follow the existing style in the file you're editing. If it conflicts with the above, match the file and mention it in the PR.
4. **Comments**: document non-obvious choices, especially workarounds. If a comment describes behaviour, make sure it still matches the code — a stale comment is worse than none.
5. **Modularity**: one concern per file.
6. **Logging**: daemons log at boundaries — entry/exit of non-trivial work, every error path, every external call. Don't remove a log line as part of an unrelated change.

### Stability Requirements

**Perseus values stability over bleeding edge.**

✅ **DO**:
- Use stable nixpkgs branches
- Test on a fresh VM before submitting
- Prefer packages in nixpkgs over overlays
- Document any workaround you can't avoid, with the reason and the condition for removing it

❌ **DON'T**:
- Add experimental or broken packages
- Add a dependency without a consumer — dead inputs are debt
- Silence a warning instead of fixing it
- Break existing functionality

### Testing Checklist

Before submitting a PR:

- [ ] `nix flake check` and `nix eval .#nixosConfigurations.<hostname>.config.system.build.toplevel` succeed
- [ ] `nix run nixpkgs#statix -- check .` and `nix run nixpkgs#deadnix -- .` are clean
- [ ] System builds and reboots
- [ ] Core functionality works (network, display, audio)
- [ ] No new findings in `ntl run`
- [ ] Changes work with **and** without `hasGPU`
- [ ] If you touched a sandbox, the app actually launches — a jail that starts and shows nothing is a silent failure

## 🔧 Development Setup

```bash
# Fork and clone
git clone https://github.com/yourusername/perseus
cd perseus

# Create feature branch
git checkout -b feature/short-description

# Test in a VM
nixos-rebuild build-vm --flake .#<hostname>
./result/bin/run-*-vm

# Test on the running system without making it the boot default
sudo nixos-rebuild test --flake .#<hostname>
```

### Local secrets

`nixup.sh` registers git clean filters that scrub `user-config.nix`, `modules/security/ssh-keys.nix`, and `hosts/default/hardware-configuration.nix` from commits. **Run it before your first commit**, or you will publish your own disk UUIDs and SSH keys. Verify with:

```bash
git diff --cached hosts/default/hardware-configuration.nix
```

The staged version should be the generic QEMU stub, not your hardware.

## 📝 Pull Request Process

1. **Branch naming**: `feature/description` or `fix/description`
2. **Commit messages**: describe the effect, not the file. "Fix ntl tray reporting zero criticals" beats "update techoverlord.nix".
3. **One concern per PR.** A refactor bundled with a bugfix is two PRs.

### PR Template

```markdown
## Description
What problem does this solve?

## Approach
What did you do, and what did you rule out?

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation

## Testing
- [ ] Tested in VM
- [ ] Tested on real hardware
- [ ] Works with GPU config
- [ ] Works without GPU config
- [ ] `ntl run` clean

## Verified vs. assumed
What did you actually run, and what are you inferring?

## Screenshots
(if UI)
```

## 🎨 Design Notes

### Theming

- **Catppuccin** is the current theme across Firefox, Thunderbird, nixvim, and DMS.
- GTK uses Juno (dark) with Papirus-Dark icons and Bibata-Modern-Amber cursors.
- Any theming PR must work in both CLI and GUI, and must not hardcode a user's paths.

### The shell

Perseus uses **Niri** + **DankMaterialShell**. DMS provides the launcher, notifications, clipboard, media controls, network menu, and lock screen. Niri handles touchpad gestures natively.

Don't add a second tool for something DMS or Niri already does — that's how the repo accumulated a dead rofi/fusuma/dunst stack that burned CPU for months doing nothing.

### `user-config.nix` is the interface

If your feature needs configuration, it goes in `user-config.nix` and gets a row in the README table. Don't add a toggle that only exists inside a module.

## 🚫 What NOT to Submit

- Anything that phones home
- Proprietary software, unless optional and sandboxed like Steam
- Major architectural changes without prior discussion
- Code copied without attribution
- Features that break existing workflows
- Workarounds where the real fix is achievable now — no `--insecure`, no skip flags, no suppressed warnings

## 💬 Getting Help

- Open an issue for discussion before major changes
- Ask in the PR if you're unsure about an approach
- Check existing modules for patterns
- `docs/perseus.d2` has the module import graph — treat it as a claim to verify, not gospel

## 🏆 Recognition

Contributors are added to the README with their area of contribution.

---

*We're building a fortress against tech overlords, not inviting them in. Every line should enhance privacy, productivity, or both.*
