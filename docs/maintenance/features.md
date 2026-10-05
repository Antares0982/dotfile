# Feature modules

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

## Feature refactoring

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
| nixos | `antares.desktop.enable`, `antares.wallpaper.enable`, `antares.rust.enable`, `antares.autostart.enable`, `antares.waitOnline.enable`, `antares.githubAuth.enable`, `services.mcp-nixos.enable` |
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
