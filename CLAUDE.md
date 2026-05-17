# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Multi-machine Nix configuration flake managing:
- `nixos` — desktop PC (x86_64-linux, KDE Plasma, NVIDIA, home-manager)
- `hk` — Hong Kong server (x86_64-linux, nginx/wordpress/mail services)
- `rpi5` — Raspberry Pi 5 (aarch64-linux)
- `wsl` — Windows Subsystem for Linux (x86_64-linux)
- `macbook` — macOS (aarch64-darwin, nix-darwin)

## Build & Switch Commands

**NixOS systems** (from this repo directory):
```bash
# Build without switching (dry-run check)
nixos-rebuild build --flake .#nixos
nixos-rebuild build --flake .#hk
nixos-rebuild build --flake .#wsl
nixos-rebuild build --flake .#rpi5

# Apply configuration
sudo nixos-rebuild switch --flake .#nixos
sudo nixos-rebuild switch --flake .#wsl
```

**macOS** (nix-darwin):
```bash
darwin-rebuild build --flake .#macbook
darwin-rebuild switch --flake .#macbook
```

**Flake inputs:**
```bash
nix flake update               # update all inputs
nix flake update <input-name>  # update a specific input
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

`systemMap.nix` is the NixOS system builder. It receives a device descriptor and:
1. Selects `nixpkgs.lib.nixosSystem` or `nixos-raspberrypi.lib.nixosSystem` for RPi
2. Builds `specialArgs` with all flake packages (myXray, antares-monitor, etc.)
3. Conditionally adds modules: home-manager, WSL, vscode-server, RPi hardware, openclaw

The mac configuration bypasses `systemMap.nix` entirely — it's built directly in `flake.nix` using `nix-darwin.lib.darwinSystem`.

### Module Dispatch

`configuration.nix` (root NixOS module) routes imports based on `currentDevice` flags:
- `currentDevice.pc` → `./pc/`
- `currentDevice.server.*` → `./server/`
- `currentDevice.rpi` → `./rpi/`
- `currentDevice.wsl` → `./wsl/`

Always imports `./common/cachix.nix` regardless of device type.

### Directory Layout

- `common/` — shared modules included by multiple device types (nix settings, zsh, agenix, gnupg, ssh, time, rabbitmq, packages)
- `pc/` — desktop-specific config (KDE, NVIDIA, audio, bluetooth, fcitx5, docker, steam, etc.)
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
