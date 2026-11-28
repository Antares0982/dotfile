# Proxy management and speed tests

## Shared Mihomo configuration

Set the three host options under `antares.proxy`. All default to false.

| Host | enable | insideGFW | lan |
|---|---|---|---|
| PC, RPi, MacBook, WSL | yes | yes | yes |
| SZ | yes | yes | no |
| HK | yes | no | no |

`enable` owns the service, subscription, clients and listeners. `insideGFW`
enables dual-stack TUN, system DNS and fail-closed egress. These hosts also
export the local proxy environment. HK applications opt in explicitly.
`lan` enables the authenticated WebUI and shares proxy listeners with the
home IPv4 network. Preserve GZ for historical evaluation only.

| Port | Purpose |
|---|---|
| 1081 | HTTP/SOCKS5, service policies; other traffic defaults to JP |
| 1082 | HTTP/SOCKS5, all traffic through GLOBAL |
| 1083 | HTTP/SOCKS5, direct |
| 17900 | MetaCubeXD `/ui/` and authenticated control API |
| 17901 | Private loopback bandwidth probes |

Home access requires the physical uplink, router 192.168.0.1, its configured
link-layer address, and client source 192.168.0.0/24. When replacing the
router, update the router identity for both platforms. Unknown networks retain
loopback access. The dashboard is on port 17900 at the host address (PC .2,
RPi .3, Mac .5). Obtain its local credential with `mihomoctl secret`.
HK and SZ expose 1081–1083 and the authenticated API exclusively on loopback.
Both omit the WebUI. Port 17901 always stays on loopback; only PC serves the
public Clash Mi override on port 18080.

```sh
mihomoctl tui
mihomoctl status
mihomoctl select JP 'exact node name'
mihomoctl update
mihomo-speed-test --refresh JP > results.json
mihomo-speed-test SG
curl --noproxy '' -x socks5h://127.0.0.1:1081 https://www.cloudflare.com/cdn-cgi/trace
```

In clashtui, press `3`, use `j/k` to select a policy or region, `l` to expand,
and Enter to choose its target. `h` returns to the group, `r` refreshes, `q` exits. Keep Rule
mode. Web UI and TUI use the same API; saved node choices survive restarts.
Nix owns ports and routing: edit `modules/mihomo-common.nix` and rebuild. Do not apply
clashtui File profiles to replace the managed daemon configuration.

Service groups are `Telegram`, `AI`, `Netflix`, `YouTube`, `国内` and `其他`.
On all hosts and mobile, Telegram defaults to SG. AI, Netflix and YouTube
follow `其他` (JP). `国内` defaults to DIRECT.
Private networks always go DIRECT; advertisements and carrier authentication
remain blocked. Service rules use upstream MRS domain/IP datasets instead of
separate JP/SG rule lists. Keep the core in Rule mode; 1082/1083 bypass those
rules through native listener targets.

1082 follows the GLOBAL selector even in Rule mode. Select SG, JP or DIRECT in
GLOBAL using the Web UI or TUI; 1081 keeps its service rules in Rule mode.
Global mode also sends 1081 through GLOBAL. The shared config defaults GLOBAL
to SG everywhere. Mihomo otherwise auto-generates GLOBAL
with DIRECT first. Saved selections override the configured default; existing
devices that saved DIRECT must select the desired region once. Restarts and
subscription updates retain that choice.

`全部节点` is an independent manual selector containing all subscription nodes,
without a region filter. Every service group and GLOBAL can select it. For
YouTube through Hong Kong, select a Hong Kong node in `全部节点`, then set
`YouTube → 全部节点` in the Web UI or TUI. Other service defaults stay unchanged.
All groups using `全部节点` share its selected node. The mobile YAML includes
this selector; update the remote override and reconnect after switching PC.

Subscriptions update hourly, rules daily. Downloads bootstrap subscriptions
through DIRECT, then fetch missing rules through JP. Empty region groups reject
connections. There is no automatic bandwidth-based selection timer.
The API credential persists under `/var/lib/mihomo-config`; node/provider
caches and selections use the native service's private state directory.
Disabling the feature preserves persistent files, including retired proxy data.

On MacBook the launchd supervisor owns the utun descriptor, routes, system
DNS and PF anchor. The core runs as the dedicated `_mihomo` account, using
private state under `/var/db/antares-mihomo`. On first activation it imports the
previous selection cache. The CLI credential and speed-test lock remain in
the user's private state. On Mac, `clashtui` and `mihomoctl tui` both use
the authenticated local API on 17900. An explicit `clashtui --config-dir`
selects a separate client configuration. The utun routes leave the zero-address
lookup available for sockets bound to the physical interface. Compare
`route -n get 223.5.5.5` (utun) with `route -n get -ifscope en0 223.5.5.5`
(physical gateway, substitute the active interface). Startup failures keep
the PF guard installed.
Use a local console for the first switch. Check the WebRTC and DoH entries
in `chrome://policy`. Test sleep, wake and moving to
another network, including one with the same IPv4 subnet.

WSL uses the distro's systemd, TUN device and resolver. In the Windows user's
`.wslconfig`, set `networkingMode=mirrored` under `[wsl2]`. Apply host changes
at a convenient `wsl --shutdown`. Check for existing Windows listeners on
1081–1083 and 17900. In elevated PowerShell, configure narrow Hyper-V rules:

```powershell
$id = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
New-NetFirewallHyperVRule -Name MihomoHomeTCP -DisplayName 'Mihomo home TCP' -Direction Inbound -VMCreatorId $id -Protocol TCP -LocalPorts 1081,1082,1083,17900 -RemoteAddresses 192.168.0.0/24
New-NetFirewallHyperVRule -Name MihomoHomeUDP -DisplayName 'Mihomo home UDP' -Direction Inbound -VMCreatorId $id -Protocol UDP -LocalPorts 1081,1082,1083 -RemoteAddresses 192.168.0.0/24
```

Verify `/dev/net/tun`, nftables, the mirrored default gateway identity, communication
from a second LAN device and isolation on another network. WSL's TUN covers
Linux processes. Windows clients can opt into port 1081.

WSL sets `antares.proxy.clientAddress = "127.0.0.2"`. Mirrored networking can
route `127.0.0.1` TCP/UDP through Windows' `loopback0` before Linux's local table.
The client address drives shell/Nix daemon URLs, API clients (including systemd
readiness), clashtui and the private bandwidth listener. `mihomo-loopback`
assigns this alternate address as a `/32` on `lo` before Mihomo starts, so the
kernel also chooses `.2` as the connection source. Without that address, replies
to the default `.1` source can still stall larger API/proxy responses.
Other hosts default to
`127.0.0.1`; LAN listener scope is independent. WSL also disables
`antares.mihomo.autoRedirect` to avoid the observed netlink `file exists` startup
error, retaining TUN `auto-route`. No priority-zero loopback rules are needed.
After changing these settings, test a fresh login shell, `mihomoctl status`,
ordinary curl and `curl --noproxy '*'`, then restart Mihomo and repeat without
temporary port 1081/17900 routing rules before switching permanently.

Windows clients use the mixed HTTP/SOCKS5 listener at `127.0.0.1:1081`.
In mirrored mode the host's connections arrive on `loopback0` with IPv4 source
and destination `127.0.0.1`. The WSL home and guard ingress chains accept TCP
and UDP on the configured mixed port for that path. This also carries the
SOCKS5 UDP relay. To test from Windows PowerShell:

```powershell
curl.exe --noproxy no-match.invalid --proxy http://127.0.0.1:1081 -I https://example.com
```

When WSL provides the Windows proxy, prefer `[wsl2] autoProxy=false` in the
Windows user's `.wslconfig`: Nix already configures Linux's proxy, and importing
Windows' `.1` proxy back into WSL can give applications the wrong endpoint.
Keep `networkingMode=mirrored`. These Windows settings require a later WSL
restart to apply; do not interrupt a live repair with `wsl --shutdown`.
Windows applications using the proxy depend on WSL/Mihomo staying available;
the WSL TUN does not automatically proxy all Windows traffic.
See Microsoft's [networking documentation](https://learn.microsoft.com/en-us/windows/wsl/networking)
and [WSL settings](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

Keep launchd script paths in the system closure using Nix path interpolation.
`toString` on a source path loses its dependency context; garbage collection can
then remove the scripts while launchd still references them. Mac checks verify
that both supervisor and preparation scripts retain their dependency context.

Bandwidth tests use BENCH and port 17901 without touching JP or SG selections.
They sample every candidate for up to three seconds, then the best three for
five seconds each. Only successful final downloads enter the ranking. JSON
version 1 reports `node`, `mbps`, bytes and timing; failures exit nonzero.
Successful results are cached for ten minutes, invalidated by subscription
updates. Tests share a host-wide lock. Downloads consume subscription traffic.
Node selection verifies egress through BENCH/17901 under the same lock and
restores BENCH afterwards. It no longer relies on a region-specific port.

RPi agents use `mihomoctl --via-worker status/select/update/restart` and
`mihomo-speed-test --via-worker --refresh JP`. A sandboxed dynamic-user worker
reads fixed action requests under `.agent/mihomo`, with its API credential
provided by systemd. The agent cannot read that credential or select outside JP.
The agent guide is installed at `.agents/skills/mihomo/SKILL.md`.

Validation: `python3 resource/test_mihomo_tools.py`,
`python3 resource/test_mihomo_darwin.py`,
`python3 scripts/check-mihomo.py` on each deployed host, and
`bash scripts/check-configs.sh`. The live check verifies both protocols, egress
regions, rule matching, direct routing, forced routing and API authentication.
The tools package also runs its regression checks during builds. Linux startup
checks execute as a systemd dynamic user without a home directory; resolve
macOS home paths only on Darwin. Configuration evaluation alone does not test
this service environment.

## TUN and DNS

Every core uses the same DNS upstream policy, including headless HK. On Linux
TUN hosts systemd-resolved sends system queries to Mihomo. Both IP families use fake IPs. Domains in the
`cn` rule set use AliDNS over direct DoH for domestic CDN selection. Default
lookups use Cloudflare DoH through `其他`. Node names and the exact subscription host
use a separate bootstrap resolver. Home-enabled hosts resolve `.lan` and `.home.arpa` through the verified home router. Chrome uses system DNS and disables unproxied WebRTC UDP.

The `mihomo-guard` service loads its own nftables table before NetworkManager.
While Mihomo is stopped, public traffic fails closed. The PC home subnet retains SSH, Samba and discovery. On SZ conntrack marks
public service connections on eth0 and routes their replies through the main
table. Verify new SSH sessions, Source queries on UDP 27015 and HTTPS on
8443 from outside while the core is stopped (`python3 scripts/check-sz-ingress.py`).
A UDP reply first selects the physical source address using its source port;
only replies to tracked incoming public connections pass the egress firewall. Set a timed rollback before switching. Direct queries to router
DNS from applications are blocked on the physical interface. qBittorrent
uses the SOCKS5 direct listener for trackers and peers. Its desktop unit
backs up only the managed proxy keys and restores them when disabled.

Run `bash scripts/check-mihomo-guard.sh` with network namespace privileges
and nftables on PATH to exercise the guard in isolation.
Test a new configuration locally with a timed rollback to the previous system
closure. Run `python3 scripts/check-mihomo.py`, then repeat the browser DNS
and WebRTC tests. During a supervised service stop, check literal public IPv4
and IPv6, UDP, raw router DNS, and LAN access from another device. Test a fresh
provider cache in a separate private runtime directory. Preserve production
state.

## Clash Mi on Android

PC enables `antares.mihomo.mobileRules` and serves
`http://192.168.0.2:18080/clashmi-pc-routing.yaml`. Only home-LAN IPv4 clients can
connect. The document root contains this public YAML override only, without
subscription credentials, nodes or the control API secret.

In Clash Mi, keep the normal Clash-format node subscription. Create a new remote
override using this URL and type `yaml`; name it `PC 分流`. Set its update
interval to one hour and appended built-in override to `内置－不覆写`. Edit the
node subscription and select this new override as its core override. Keep Rule
mode and Android TUN enabled, update once and reconnect. Retire the previous JS
override after binding the YAML version; the old `.js` URL is no longer served.
This URL belongs in the remote override field, not an individual rule provider.

The phone keeps its own nodes, subscription updates, ports and control API.
The override uses the PC's effective DNS, IPv6 and routing rules, including
the `cn` resolver policy and final `MATCH,REJECT`.
It also enables TUN on Android.
Proxy groups and rule providers come from `antares.mihomo.policy`.
Regional groups use native `include-all`
and filters to discover the phone's nodes, so no subscription-name adaptation
or JavaScript is required.
Old subscription policy groups and rules are replaced rather than retained.
Select `Telegram → SG`, `其他 → JP`, and `国内 → DIRECT` in the phone dashboard.
Each device stores its own selections; PC Web UI changes do not synchronize.

### Keeping PC and mobile in sync

When changing PC Mihomo behavior, share every feature that Clash Mi can use.
Define public routing rules, groups and providers once in `modules/mihomo-common.nix`.
For portable core settings such as DNS, export the effective PC value from
`settings` in `modules/mihomo.nix` after the TUN overlay has been applied.
When introducing a new portable field, include it in the mobile export and
compare it with the PC template in `resource/test_mihomo_mobile.py` in the same change.
Keep Linux interface settings, nftables and Chrome policies on the PC.
Clash Mi manages Android VPN routing and app selection. Keep credentials,
node subscriptions and control listeners private to each device.

Switching the PC publishes the generated YAML at the existing LAN URL.
On the phone, update the bound remote override and reconnect to apply it.
Rule-provider datasets refresh independently each day. The service sends
fresh content even when a client caches the normalized Nix store timestamp.

Clash Mi checks overdue remote overrides on startup, returning to the foreground
and VPN connection. Its Android implementation does not run the desktop's
periodic timer, so the interval is not a guaranteed background schedule. Open
the app at home to trigger an overdue update; reconnect to apply it. Off-LAN
or while PC is asleep, failed downloads preserve the last downloaded file.
See the [upstream implementation](https://github.com/KaringX/clashmi/blob/main/lib/app/modules/profile_patch_manager.dart).

Validate a generated override against the public `mihomo-base.json` template
passed to `mihomo-config.service` with
`python3 resource/test_mihomo_mobile.py GENERATED_YAML PC_TEMPLATE_JSON` (with PyYAML), and run
`bash scripts/check-configs.sh nixos rpi5`. After switching, fetch the URL from
another LAN device and run the normal live proxy check.
