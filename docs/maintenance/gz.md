# GZ server

HK and GZ import `server` for fail2ban, sysstat, and firewall activation.
HK-specific hardware, accounts, packages, and service integrations live in
`server/hk`; GZ-specific configuration lives in `server/gz`. GZ deploys
`serverPassword` and its enabled Xray secrets with its dedicated
`/etc/ssh/agenix` identity. The local SSH
alias `gz` uses `antares` and `~/.ssh/gz`; root SSH is disabled. Its disko layout
targets `/dev/vda` with BIOS GRUB and ext4. Installation erases that disk;
ordinary rebuilds do not repartition it.

GZ uses `services.xray.enable` and `antares.proxy.enable`. Its native Xray
service reads `/var/xray/config.json`; proxy variables cover login shells and
the Nix daemon. All proxy listeners are loopback-only. `xs` selects nodes and
restarts the system service through sudo. `sudo systemctl start xray-sub`
updates subscriptions manually; a timer also runs after boot and daily.
Updates retain the selected node when available, otherwise test Japan nodes
before trying all nodes. Failed updates retain the previous configuration.
GZ's `serverPassword.age`, `xraysub.age`, and `xray-template-gz.age` authorize its existing agenix key
alongside the PC management key; shared files also authorize their other consumers.
The GZ template is a snapshot of the PC template with loopback listeners.

## Deployment

Read [build and deployment](build.md) before rebuilding, and
[secrets and identities](secrets.md) before changing keys or secret consumers.
L4D2-specific work also requires the [L4D2 guide](l4d2.md).
