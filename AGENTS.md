# AGENTS.md

## Approach
- Read existing files before writing. Don't re-read unless changed.
- Thorough in reasoning, concise in output.
- Skip files over 100KB unless required.
- No sycophantic openers or closing fluff.
- No emojis or em-dashes.
- Do not guess APIs, versions, flags, commit SHAs, or package names. Verify by reading code or docs before asserting.

## Repository Overview

Multi-machine Nix configuration flake managing:
- `nixos` — desktop PC (x86_64-linux, niri/Wayland, NVIDIA, home-manager)
- `hk` — Hong Kong server (x86_64-linux, nginx/mail services)
- `gz`: Guangzhou VPS (x86_64-linux, basic SSH server)
- `rpi5` — Raspberry Pi 5 (aarch64-linux)
- `wsl` — Windows Subsystem for Linux (x86_64-linux)
- `macbook` — macOS (aarch64-darwin, nix-darwin)

## Build & Switch Commands

Each machine is its own flake under `hosts/<name>/`, with an independent
`flake.lock` (so one machine's nixpkgs pin never affects another). Shared Nix
code stays at the repo root and is pulled in via `import ../../<file>`. There is
no root `flake.nix`.

Do not build a host whose system platform differs from the current machine.
For those hosts, only run local evaluation; perform full builds on a matching
host or an explicitly configured remote builder.

**NixOS systems** (from this repo directory):
```bash
# Build without switching (dry-run check)
nixos-rebuild build --flake ./hosts/nixos#nixos
nixos-rebuild build --flake ./hosts/hk#hk
nixos-rebuild build --flake ./hosts/gz#gz
nixos-rebuild build --flake ./hosts/wsl#wsl
nixos-rebuild build --flake ./hosts/rpi5#rpi5

# Apply configuration
sudo nixos-rebuild switch --flake ./hosts/nixos#nixos
sudo nixos-rebuild switch --flake ./hosts/wsl#wsl

# Deploy GZ with its dedicated key
nixos-rebuild switch --flake ./hosts/gz#gz --target-host gz --sudo
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

### Host Composition

`hosts/{nixos,hk,rpi5,macbook}/configuration.nix` is the feature selection entry
point. Each host explicitly imports its role modules, selects features, and
provides host-specific package arguments through `_module.args`.

`systemMap.nix` constructs NixOS systems and selects the Raspberry Pi builder
when required. Its `specialArgs` are `inputs`, `currentDevice`, and `agenix`.
It imports platform modules, Home Manager, and agenix; feature activation and
business package selection belong to host or feature modules.

The macbook flake uses `nix-darwin.lib.darwinSystem` directly. WSL keeps its
existing flake and `configuration.nix` dispatch path and is outside this
refactoring.

Use `inputs` for upstream module imports. `_module.args` is for ordinary
package dependencies, never for choosing imports. Imports stay static;
`mkIf` controls feature configuration.

### Device Metadata

`_make-device.nix` and the root device descriptors retain platform metadata and
legacy compatibility. New business features use module options, not device
flags. Proxy consumers in migrated hosts read `antares.proxy`; shared modules
retain the descriptor fallback for the excluded WSL configuration.

`common/localFileDef.nix` derives user directory conventions. Human and shared
accounts remain in user modules. Dedicated service accounts belong to their
feature modules.

### Module Ownership

- `hosts/<name>/`: independent flake, lock file, and host choices.
- `modules/`: reusable feature implementations and shared option definitions.
- `common/`: shared base configuration and service policy.
- `pc/`, `rpi/`, `server/`, `mac/`: platform configuration and feature integrations.
- `packages/`: package construction without activation or account configuration.
- `secrets/`: encrypted sources and recipient authorization.
- `resource/`: scripts and static assets.

Features own their dedicated services, accounts, groups, secret deployments,
timers, paths, generators, activation hooks, packages, and firewall contributions.
Cross-feature integration exists only while its consumers are enabled. Shared
infrastructure and shared accounts remain independent.

## Secrets

Secrets use agenix. Edit encrypted sources with `agenix -e`; recipient keys
remain in `secrets/secrets.nix`. Feature modules declare their own
`age.secrets` entries and consume `config.age.secrets.<name>.path`.

`common/agenix.nix` owns agenix tooling, identity paths, and base account password
secrets. QQ relay and QQ Codex share the deployment in `rpi/qq-credentials.nix`;
it remains while either consumer is enabled.

GZ uses `server/gz` without the broader `server` imports. It deploys only
`serverPassword` with its dedicated `/etc/ssh/agenix` identity. The local SSH
alias `gz` uses `antares` and `~/.ssh/gz`; root SSH is disabled. Its disko layout
targets `/dev/vda` with BIOS GRUB and ext4. Installation erases that disk;
ordinary rebuilds do not repartition it.
For `nixos-anywhere --extra-files`, explicitly set the staging directories
`etc` and `etc/ssh` to mode 0755 and the `agenix` private key to 0600; tar
preserves these directory permissions on the installed system.

## Custom Packages

`packages/default.nix` is the explicit package entry point. Import it with
`{ inherit pkgs; }`, adding `myXray` when selecting `xs`. Configure `xs` variants
with `.override`. Package selection stays lazy so platform-specific packages
are evaluated only by their consumers. Do not add directory discovery or a
second package registry.

## Feature Refactoring

The refactoring covers `nixos`, `hk`, `rpi5`, and `macbook`. WSL is excluded;
keep its existing entry points and shared-module interfaces compatible.

Run `bash scripts/check-configs.sh` for all configured checks, or pass host names.
The check evaluates locked configurations and feature scenarios without switching.
Stage new Nix files before evaluating Git-backed flakes.

Host configurations select features. Feature modules own their services,
dedicated account declarations, secret deployments, timers, permissions, and
network contributions. Shared accounts and infrastructure remain independent.
Disabling a feature never deletes persistent data or encrypted secret sources.
Commit and validate one feature migration before starting the next.

### Feature Controls

Edit the relevant host configuration; disabling a feature does not require
removing its imports. Native service options control their repository-specific
integration as well as the upstream service.

| Host | Controls |
|---|---|
| nixos, hk, rpi5 | `services.telegram-output-monitor-bot.enable`, `services.antares-rpc-client.enable`, `services.rabbitmq.enable` |
| nixos, rpi5, macbook | `antares.xray.enable`, `antares.proxy.enable` |
| rpi5 | `services.antares-runners.instances.<name>.enable`, `antares.agent.enable`, `antares.qq.enable`, `antares.gitServer.enable`, `services.ssh-probe.enable` |
| hk | `antares.blog.enable`, `antares.blog.metrics.enable`, `antares.messaging.enable`, `mailserver.enable`, `services.mysql.enable`, `services.nginx.enable`, `antares.acme.enable`, `services.xray.enable` |
| nixos | `antares.desktop.enable`, `antares.rust.enable`, `antares.autostart.enable`, `antares.waitOnline.enable`, `antares.githubAuth.enable`, `services.mcp-nixos.enable` |
| nixos | `services.pipewire.enable`, `hardware.bluetooth.enable`, `i18n.inputMethod.enable`, `services.samba.enable`, `programs.steam.enable`, `programs.ydotool.enable` |
| macbook | `antares.nixShell.enable`, `antares.systemCompiler.enable` |

QQ components use `antares.qq.{napcat,relay,codex}.enable`. HK messaging components
use `antares.alice.enable`, `antares.trilug.enable`,
`services.telegram-bot-api.enable`, and `antares.agentFiles.enable`.
A stack's master switch dominates component selections. Blog metrics also
require the blog master switch.

### Dependencies and State

- QQ relay and QQ Codex require NapCat. Alice requires agent file exchange.
- Web features require nginx; configured certificates require ACME.
- Blog metrics require MySQL. The host ties MySQL backup activation to MySQL.
- The local proxy environment requires Xray. Desktop autostart also requires
  Xray because its external script invokes Xray tools.
- Agent-triggered Xray actions require both agent and Xray to be enabled.
- Remote broker endpoints and external application scripts remain external
  runtime dependencies; local service ordering does not establish ownership.

Missing required components produce evaluation assertions. Disable the whole
stack with its master switch, or explicitly disable its consumers first.
Disabling a feature removes declarations, not persistent data. Keep the existing
user-management policy; do not add `userdel`, recursive removals, database drops,
or automatic secret-source deletion. Shared `antares` and `alice` accounts stay.

HK retains the explicit `couch.chr.fan` certificate and legacy UDP ports in its
host configuration. Mail owns its certificates independently of the blog.
Nginx virtual hosts use `acmeRoot = null` to retain Cloudflare DNS challenges.
Historical database backups remain when blog metrics are disabled.

RPi runners use the host flake's nixpkgs, independently of the Raspberry Pi
system nixpkgs. Preserve existing unit names, users, homes, registration data,
and package sources. Keep `indexed = true` for SSRJSON even when reducing its
instance count to one.

### Validation

`bash scripts/check-configs.sh` evaluates the four scoped hosts and GZ. To check one
feature while editing, use e.g.
`CHECK_CASE='blog-off|metrics-off' bash scripts/check-configs.sh hk`.
Checks cover individual shutdown, shared resources, invalid dependencies, and
complete business-feature shutdown. They do not decrypt secrets or activate
configurations. Continue to build only on matching platforms or explicitly
configured remote builders.
