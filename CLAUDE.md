# CLAUDE.md

## Approach
- Read existing files before writing. Don't re-read unless changed.
- Thorough in reasoning, concise in output.
- Skip files over 100KB unless required.
- No sycophantic openers or closing fluff.
- No emojis or em-dashes.
- Do not guess APIs, versions, flags, commit SHAs, or package names. Verify by reading code or docs before asserting.

## Repository Overview

Multi-machine Nix configuration flake managing:
- `nixos` — desktop PC (x86_64-linux, KDE Plasma, NVIDIA, home-manager)
- `hk` — Hong Kong server (x86_64-linux, nginx/wordpress/mail services)
- `rpi5` — Raspberry Pi 5 (aarch64-linux)
- `wsl` — Windows Subsystem for Linux (x86_64-linux)
- `macbook` — macOS (aarch64-darwin, nix-darwin)

## Build & Switch Commands

Each machine is its own flake under `hosts/<name>/`, with an independent
`flake.lock` (so one machine's nixpkgs pin never affects another). Shared Nix
code stays at the repo root and is pulled in via `import ../../<file>`. There is
no root `flake.nix`.

**NixOS systems** (from this repo directory):
```bash
# Build without switching (dry-run check)
nixos-rebuild build --flake ./hosts/nixos#nixos
nixos-rebuild build --flake ./hosts/hk#hk
nixos-rebuild build --flake ./hosts/wsl#wsl
nixos-rebuild build --flake ./hosts/rpi5#rpi5

# Apply configuration
sudo nixos-rebuild switch --flake ./hosts/nixos#nixos
sudo nixos-rebuild switch --flake ./hosts/wsl#wsl
```

**macOS** (nix-darwin):
```bash
darwin-rebuild build --flake ./hosts/macbook#macbook
darwin-rebuild switch --flake ./hosts/macbook#macbook
```

**Flake inputs** (per machine — updates only that machine's lock):
```bash
nix flake update --flake ./hosts/nixos                 # update all inputs
nix flake update nixpkgs --flake ./hosts/nixos         # update a specific input
```

**Secrets** (requires `~/.ssh/agenix` key):
```bash
agenix -e secrets/<name>.age
```

## Architecture

### Device Abstraction

`_make-device.nix` is the device descriptor factory. Each machine file (`pc.nix`, `hk.nix`, `wsl.nix`, `rpi5.nix`, `mac.nix`) calls it with flags:
- `pc`, `mac`, `rpi`, `wsl`, `server` — device type flags
- `system` — Nix system string (e.g. `"x86_64-linux"`)
- `useProxy` — injects `http_proxy`/`https_proxy` env vars (127.0.0.1:1081) and configures `nix-daemon` proxy
- `withHm` — enables home-manager as a NixOS module

### System Construction

`systemMap.nix` is the NixOS system builder. Each `hosts/<name>/flake.nix` calls
it as `import ../../systemMap.nix inputs (import ../../<device>.nix)`, where
`inputs` is that host flake's own inputs. It:
1. Accesses every flake input lazily through `inputs` (e.g. `inputs.wsl`), so a
   host flake only declares the inputs its device actually forces. An omitted
   input errors only if a module for that device reads it (which never happens).
2. Selects `nixpkgs.lib.nixosSystem` or `nixos-raspberrypi.lib.nixosSystem` for RPi
3. Builds `specialArgs` with all flake packages (myXray, antares-monitor, etc.)
4. Conditionally adds modules: home-manager, WSL, vscode-server, RPi hardware, openclaw

The mac configuration bypasses `systemMap.nix` entirely — `hosts/macbook/flake.nix`
builds it directly with `nix-darwin.lib.darwinSystem`.

### Module Dispatch

`configuration.nix` (root NixOS module) routes imports based on `currentDevice` flags:
- `currentDevice.pc` → `./pc/`
- `currentDevice.server.*` → `./server/`
- `currentDevice.rpi` → `./rpi/`
- `currentDevice.wsl` → `./wsl/`

Always imports `./common/cachix.nix` regardless of device type.

### Directory Layout

- `hosts/<name>/` — per-machine flake (`flake.nix` + independent `flake.lock`); the flake entry point for each device
- `common/` — shared modules included by multiple device types (nix settings, zsh, agenix, gnupg, ssh, time, rabbitmq, packages)
- `pc/` — desktop-specific config (KDE, NVIDIA, audio, bluetooth, fcitx5, steam, etc.)
- `server/` — server config; `server/hk/` and `server/gz/` for region-specific services
- `wsl/` — WSL-specific network and user config
- `rpi/` — Raspberry Pi 5 config (xray, monitor, runner services)
- `mac/` — nix-darwin config (packages, proxy, xray)
- `secrets/` — agenix-encrypted `.age` files; `secrets/secrets.nix` defines which SSH keys can decrypt each secret
- `resource/` — static assets (fonts, jars, scripts for build tooling)
- `common/cachix/` — auto-generated cachix substituter configs (overwritten by `cachix use`)

### `currentDevice` in Modules

All NixOS modules receive `currentDevice` as a `specialArg`. Use `currentDevice.pc`, `currentDevice.server.hk`, etc. for conditional configuration. The `common/localFileDef.nix` utility derives standard path conventions (home, Documents, GitHub dirs) from a username.

### Secrets

Secrets are managed with [agenix](https://github.com/ryantm/agenix). The identity key is at `~/.ssh/agenix`. Available secrets: `password`, `serverPassword`, `superUserAuthorizedKey`, `gitAuthorizedKey`. Access via `config.age.secrets.<name>.path` in modules.

### Custom Packages

`pc/_switch.nix` builds `_switch` — a Python (pydotool) + shell script for KDE desktop switching. It patches the script shebangs at build time with `substituteInPlace`.
