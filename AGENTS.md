# AGENTS.md

## Repository overview

Multi-machine Nix configuration flake managing:

- `nixos`: desktop PC (x86_64-linux, niri/Wayland, NVIDIA, home-manager)
- `hk`: Hong Kong server (x86_64-linux, nginx/mail services)
- `gz`: Guangzhou VPS (x86_64-linux, Xray and L4D2)
- `sz`: Shenzhen VPS (x86_64-linux, UEFI, Xray and L4D2)
- `rpi5`: Raspberry Pi 5 (aarch64-linux)
- `wsl`: Windows Subsystem for Linux (x86_64-linux)
- `macbook`: macOS (aarch64-darwin, nix-darwin)

Each machine has an independent flake and lock under `hosts/<name>/`.
There is no root `flake.nix`. Shared Nix code is imported from the repo root.

- `hosts/`: host choices, inputs, and locks.
- `modules/`: reusable features and shared options.
- `common/`: shared base configuration and policy.
- `pc/`, `rpi/`, `server/`, `mac/`: platform integrations.
- `packages/`: package construction; `resource/`: scripts and static assets.
- `secrets/`: encrypted sources; `scripts/` and `tests/`: validation.

## Always preserve

- Build only for the current platform or an explicitly configured remote builder;
  use local evaluation for other platforms.
- Keep WSL's existing entry points and shared-module interfaces compatible.
- Host configurations select features; features own their dedicated resources.
  Shared infrastructure and accounts remain independent.
- Imports stay static. Use `inputs` for upstream module imports, `_module.args`
  for package dependencies, and `mkIf` for feature configuration.
- Disabling features removes declarations, never persistent data or encrypted
  sources. Keep shared accounts; do not add automatic destructive cleanup.
- Private keys and plaintext secrets must never enter Git or the Nix store.
  Never copy the PC management key to servers.

## Read only what the task needs

Before editing or running maintenance commands, read the matching guides below.
Match both the task and affected files, including cross-directory consumers.
Read multiple guides only when the task spans their topics. Do not preload all
of `docs/maintenance/`. Paths in guides are repository-relative; commands run
from the repository root.

These are explicit reading instructions: Markdown links do not auto-include
files. If scope expands, read the newly relevant guide before proceeding.
Keep universal rules here and put new specialist details in the matching guide.

| Task or affected area | Read first |
|---|---|
| Build, switch, deploy, update flake inputs, or choose configuration checks | [Build and deployment](docs/maintenance/build.md) |
| Add, disable, or migrate features; change module composition, options, dependencies, accounts, or feature tests | [Feature modules](docs/maintenance/features.md) |
| Secrets, passwords, agenix recipients/identities, secret consumers, or installation key staging | [Secrets and identities](docs/maintenance/secrets.md) |
| GZ/SZ hosts, SSH, disks, or Xray: `hosts/{gz,sz}/`, `server/{gz,sz}/`, `server/vps.nix`, `server/xray-client.nix`, `{gz,sz}.nix` | [GZ and SZ servers](docs/maintenance/gz.md) |
| L4D2 server, addons, downloads, RCON, or related auth: `modules/l4d2*.nix`, `resource/l4d2/`, L4D2 scripts/secrets/options | [L4D2](docs/maintenance/l4d2.md) |
| Wallpaper, we-layerd assets, period configs, or wallpaper checks | [PC wallpaper](docs/maintenance/wallpaper.md) |
| Zsh, prompts, shell environment, completion, or fzf integration | [Zsh](docs/maintenance/zsh.md) |

## Custom packages

`packages/default.nix` is the explicit package entry point. Import it with
`{ inherit pkgs; }`, adding `myXray` when selecting `xs`. Configure `xs` variants
with `.override`. Package selection stays lazy so platform-specific packages
are evaluated only by their consumers. Do not add directory discovery or a
second package registry.

## Validation

For Nix configuration changes, run `bash scripts/check-configs.sh <host> ...`;
omit hosts for all seven. These checks evaluate locked configurations without
switching. Stage new Nix files before evaluating Git-backed flakes.
Use the relevant guide for feature-specific checks. For documentation-only
changes, check links and `git diff --check`; no system build is needed.
