# PC wallpaper

PC wallpaper configuration lives in `pc/wallpaper.nix` and is gated by the
desktop switch. Assets and selected workshop directories live outside Nix at
`/var/lib/we-layerd/{assets,workshop/<ID>}`; provision them separately with read
access for the desktop user and greeter. HM owns the three period configs and
user timer. Run `bash scripts/check-wallpaper.sh`; optionally pass the generated
config directory to also validate TOML using Python 3.11 or newer, and the
generated greeter TOML as a second argument to check its resource path too.

Configs select resources through fixed symlinks in `/var/lib/we-layerd/current`.
The directory is `0755 root root`; systemd tmpfiles `L` rules create missing links
with these defaults, preserving existing links (including dangling links) across
rebuilds and reboots. Disabling wallpapers removes declarations, not resources
or existing links.

| Link | Default workshop ID |
|---|---|
| `day-main` | `3759473977` |
| `day-secondary` | `3657215414` |
| `evening-main` | `3545541611` |
| `evening-secondary` | `3780257889` |
| `night-main` | `3222456142` |
| `night-secondary` | `3780257889` |
| `greeter` | `3482954869` |

Main is `HDMI-A-5`; secondary is `HDMI-A-1`. Day runs 06:00–19:00, evening
19:00–00:00, and night 00:00–06:00. Each link can be changed independently.
Apply this configuration with one initial rebuild, then replace links without
editing Nix or rebuilding (replace `<ID>` with the desired workshop ID):

```bash
sudo ln -sfnT "/var/lib/we-layerd/workshop/<ID>" /var/lib/we-layerd/current/day-main
systemctl --user restart we-layerd.service
```

The target must exist and be readable by the desktop user and, for the login
wallpaper, greeter. Restart selects the current period and reopens its resources;
replacing a link alone is not watched. Use restart because the existing reload
command uses `switch`, which can skip unchanged configuration paths. A changed
`greeter` link takes effect the next time the greeter starts.

## Temporary desktop override

After rebuilding, run `we-wallpaper /path/to/workshop/item` to show the same
wallpaper on both desktop outputs. The directory must contain a readable, valid
`project.json`. Run `we-wallpaper` without arguments to restore the current time
period's configuration. Paths with spaces are supported when quoted.

The override lives in `$XDG_RUNTIME_DIR`, keyed by the niri session socket.
Scheduled switches leave it intact, and wallpaper service restarts reuse it.
A new niri session or reboot starts without the override. Persistent configs,
the greeter, and links under `/var/lib/we-layerd/current` are unchanged.
Invalid resources are rejected before restarting; application failures restore
the previous override and attempt to restart the previous configuration.

On 2026-10-25, `day-main` and `evening-main` pointed into the missing directory
`~/.wall-paper-engine-workshop`. The renamed directory is
`~/.wallpaper-engine-workshop`, a link to Steam's workshop content. Both links
were repaired to use that path, retaining IDs `3424649201` and `3545541611`.
The two `*-backup` links still point to valid provisioned resources. The
non-forcing tmpfiles `L` rules intentionally preserve these local choices;
rebuilding does not repair a dangling link.
