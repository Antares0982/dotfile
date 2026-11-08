# SZ server and GZ history

GZ will not be renewed. Keep its Nix configuration and lock as historical
reference; routine deployment and input updates target SZ. GZ's agenix key is
no longer authorized for current secrets. Formerly authorized encrypted files remain available for active consumers
or PC-only recovery; obsolete proxy templates have no active consumers.
See [secrets and identities](secrets.md) for the limits of recipient revocation
and cleanup before releasing the server.

## Historical GZ configuration

HK, GZ, and SZ import `server` for fail2ban, sysstat, and firewall activation.
HK-specific hardware, accounts, packages, and service integrations live in
`server/hk`; host-specific configuration lives in `server/gz` and `server/sz`.
Both VPS hosts import `server/vps.nix`, which imports the shared Mihomo and proxy
modules. The retained GZ declaration follows SZ but must not be deployed; its
`/etc/ssh/agenix` identity has no current secret access. The local SSH
alias `gz` uses `antares` and `~/.ssh/gz`; root SSH is disabled. Its disko layout
targets `/dev/vda` with BIOS GRUB and ext4. Installation erases that disk;
ordinary rebuilds do not repartition it.

SZ uses `antares.mihomo.enable` and `antares.proxy.enable`. Mihomo supplies
HTTP/SOCKS5 on 1081, GLOBAL on 1082, and DIRECT on 1083. All listeners and the
authenticated control API are loopback-only, with no WebUI. Use `mihomoctl tui`
for policy and node selection, `mihomoctl update` for subscription refresh, and
`mihomo-speed-test JP` or `SG` for bandwidth measurements. Subscriptions refresh
hourly and rule providers daily. Shells and the Nix daemon use 1081.
See [proxy management](proxy.md) for routing and acceptance checks.

## Deployment

Read [build and deployment](build.md) before rebuilding, and
[secrets and identities](secrets.md) before changing keys or secret consumers.
L4D2-specific work also requires the [L4D2 guide](l4d2.md).

## SZ installation and deployment

SZ (`sz.chr.fan`, currently `39.108.115.13`) is an x86_64 KVM VPS.
Its independent flake is `hosts/sz`, initially using GZ's locked inputs.
The initial installation used nixos-anywhere 1.13.0, revision
`3c6e0cc24fbc69b97a22cf09bb6ca361354e0490`.
Its 80 GB `/dev/vda` uses GPT, a 1 GiB FAT32 `/boot`, and ext4 `/`.
Unlike GZ's BIOS boot, SZ uses removable-path EFI GRUB without writing NVRAM.
Both retain eth0 DHCP, serial console, zram, and the same service policy.

Local SSH aliases `sz` and `sz-l4d2` use `~/.ssh/sz` and `~/.ssh/sz-l4d2`.
The former logs in as `antares`, with passwordless sudo; root SSH is disabled.
SZ's separate `~/.ssh/sz-agenix` recovery copy provisions `/etc/ssh/agenix`.
The factory `_SZ1.pem` key is no longer authorized.

Build locally with remote builders disabled, then deploy:

```bash
bash scripts/check-configs.sh sz hk
nixos-rebuild switch --flake ./hosts/sz#sz --target-host sz --sudo --option builders ''
```

For a fresh install, validate the extra-files tree with
`bash scripts/check-install-files.sh EXTRA_FILES_ROOT` before running
nixos-anywhere. Keep the parent staging directory private (0700), but the
copied root, `etc`, and `etc/ssh` directories must be 0755. All private keys
must be 0600 and installed as root:root. Never recursively chmod this tree.
Run `--phases kexec,disko,install`, inspect `/mnt` permissions, authorized keys,
secret decryption, SSH configuration, and `/boot/EFI/BOOT/BOOTX64.EFI`, then
reboot. Preserve SZ's own SSH host keys, never GZ's keys.

### Historical GZ-to-SZ migration

The following procedure records the original migration while GZ was available.
For future restores, use retained backups instead of relying on GZ.

When restoring game data, temporarily remove `wantedBy` from `l4d2`,
`l4d2-install`, and `l4d2-update.timer` in the installation configuration.
Copy the game files before switching to the normal host configuration.
Pre-copy online, briefly stop GZ's game and update timer for the final delta,
and always restore its previous running state. Copy `serverfiles`, `.steam`,
and `.local`; exclude SSH credentials and generated RCON/private config files.
Restore SZ ownership by account name, never GZ's numeric IDs.
