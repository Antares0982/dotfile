# Build and deployment

Run commands from the repository root.

Each machine is its own flake under `hosts/<name>/`, with an independent
`flake.lock` (so one machine's nixpkgs pin never affects another). Shared Nix
code stays at the repo root and is pulled in via `import ../../<file>`. There is
no root `flake.nix`.

Do not build a host whose system platform differs from the current machine.
For those hosts, only run local evaluation; perform full builds on a matching
host or an explicitly configured remote builder.

Build HK, GZ, and SZ locally with remote builders disabled, then push their closures;
build RPi on an aarch64 host. For GZ/SZ deployment, read the [GZ guide](gz.md).
For key provisioning or rotation, read [secrets and identities](secrets.md).

**NixOS systems** (from this repo directory):
```bash
# Build without switching
nixos-rebuild build --flake ./hosts/nixos#nixos
nixos-rebuild build --flake ./hosts/hk#hk
nixos-rebuild build --flake ./hosts/gz#gz
nixos-rebuild build --flake ./hosts/sz#sz
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

**Flake inputs** (per machine; updates only that machine's lock):
```bash
nix flake update --flake ./hosts/nixos                 # update all inputs
nix flake update nixpkgs --flake ./hosts/nixos         # update a specific input
```

## Configuration checks

`bash scripts/check-configs.sh` evaluates all seven hosts, including WSL. To check one
feature while editing, use e.g.
`CHECK_CASE='blog-off|metrics-off' bash scripts/check-configs.sh hk`.
Checks cover individual shutdown, shared resources, invalid dependencies, and
complete business-feature shutdown. They do not decrypt secrets or activate
configurations. Continue to build only on matching platforms or explicitly
configured remote builders.
