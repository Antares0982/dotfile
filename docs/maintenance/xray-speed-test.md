# Proxy management and speed tests

## Mihomo on nixos, rpi5 and macbook

These hosts use `antares.mihomo.enable`. The shared module owns the native
Mihomo service, subscription secret, Web UI, management commands and optional
RPi agent worker. Disable `antares.proxy.enable` when disabling the last proxy.
SZ and the other Xray consumers retain the legacy tools described below.

| Port | Purpose |
|---|---|
| 1081 | HTTP/SOCKS5, service policies; other traffic defaults to JP |
| 1082 | HTTP/SOCKS5, all traffic through GLOBAL |
| 1083 | HTTP/SOCKS5, direct |
| 17900 | MetaCubeXD `/ui/` and authenticated control API |
| 17901 | Private loopback bandwidth probes |

Ports 1080 and 1084 are retired. PC listeners are loopback-only. RPi permits proxy and
dashboard access from `192.168.0.0/24` on `end0`; firewall rules deny public IPv6 access.
Dashboard URLs: `http://127.0.0.1:17900/ui/` locally and
`http://192.168.0.3:17900/ui/` for RPi. Run `mihomoctl secret` on the target host
to obtain its API password. Never put the password in Git or Nix expressions.

MacBook uses `http://192.168.0.5:17900/ui/` on the home LAN. Its proxy ports
remain loopback-only; the control API listens on IPv4, with a dedicated PF
anchor permitting only loopback and `192.168.0.0/24`. `dashboardLan` controls
dashboard exposure independently of `lan`, which controls proxy listeners.
`dashboardOrigins` declares additional Web UI origins. In the dashboard setup,
use the API address without `/ui/` and the target host's `mihomoctl secret`.

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
On PC/Mac/mobile, Telegram defaults to SG; AI, Netflix and YouTube follow `其他`,
which defaults to JP. `国内` defaults to DIRECT. RPi retains JP as its only
dedicated region group. `singapore` enables the SG group, without adding a listener.
Private networks always go DIRECT; advertisements and carrier authentication
remain blocked. Service rules use upstream MRS domain/IP datasets instead of
separate JP/SG rule lists. Keep the core in Rule mode; 1082/1083 bypass those
rules through native listener targets.

1082 follows the GLOBAL selector even in Rule mode. Select SG, JP or DIRECT in
GLOBAL using the Web UI or TUI; 1081 keeps its service rules in Rule mode.
Global mode also sends 1081 through GLOBAL. The shared config defaults GLOBAL
to SG on PC/Mac/mobile and JP on RPi. Mihomo otherwise auto-generates GLOBAL
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
Disabling the feature preserves these files and old Xray data for rollback.

On MacBook, `org.nixos.mihomo` supervises the core under launchd. The supervisor
sets up PF and the application firewall before starting Mihomo as `antares`;
the core never runs as root. Exit cleanup removes only this service's firewall
entries and PF enable reference. State, credentials and the bandwidth lock live
under `~/Library/Application Support/mihomo`, with private directory/file modes.
The supervisor waits for agenix on boot and retries failed startups through
launchd. Logs are in `/var/log/mihomo.log` (root-only). Mac configuration updates
require `sudo darwin-rebuild switch --flake ./hosts/macbook#macbook`; preserve the
previous system closure for rollback. `opencode` is temporarily omitted on Mac
until its Darwin build is fixed.

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
The existing `xray-switch` skill entry is updated for this protocol.

Validation: `python3 resource/test_mihomo_tools.py`,
`python3 resource/test_mihomo_darwin.py`,
`python3 scripts/check-mihomo.py` on each deployed host, and
`bash scripts/check-configs.sh`. The live check verifies both protocols, egress
regions, direct routing, forced routing, domain blocking and API authentication.
The tools package also runs its regression checks during builds. Linux startup
checks execute as a systemd dynamic user without a home directory; resolve
macOS home paths only on Darwin. Configuration evaluation alone does not test
this service environment.

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
The published `proxy-groups`, `rules` and `rule-providers` come directly from
`antares.mihomo.policy`, also used by PC. Regional groups use native `include-all`
and filters to discover the phone's nodes, so no subscription-name adaptation
or JavaScript is required. DNS is shared and the mobile override enables TUN.
Old subscription policy groups and rules are replaced rather than retained.
Select `Telegram → SG`, `其他 → JP`, and `国内 → DIRECT` in the phone dashboard.
Each device stores its own selections; PC Web UI changes do not synchronize.

After editing the Nix routing settings, rebuild and switch PC to publish the
new override automatically. Merely editing the repository does not publish.
Rule-provider datasets still refresh independently each day. The service avoids
HTTP timestamp caching because Nix store files share normalized timestamps.

Clash Mi checks overdue remote overrides on startup, returning to the foreground
and VPN connection. Its Android implementation does not run the desktop's
periodic timer, so the interval is not a guaranteed background schedule. Open
the app at home to trigger an overdue update; reconnect to apply it. Off-LAN
or while PC is asleep, failed downloads preserve the last downloaded file.
See the [upstream implementation](https://github.com/KaringX/clashmi/blob/main/lib/app/modules/profile_patch_manager.dart).

Validate a generated override against public settings with
`python3 resource/test_mihomo_mobile.py GENERATED_YAML PUBLIC_JSON` (with PyYAML), and run
`bash scripts/check-configs.sh nixos rpi5`. After switching, fetch the URL from
another LAN device and run the normal live proxy check.

## Legacy Xray speed tests

`xray-speed-test [FILTER]` measures nodes without selecting one or restarting
Xray. `FILTER` is a case-sensitive literal filename substring, defaults to
`XS_FILTER` or `Japan`, and can be empty to match all nodes. Use `-- FILTER` for
filters starting with a dash. `XRAY_CONF_DIR` selects the parent of
`subscriptions/` unless a host-specific Nix package override supplies it.

```bash
xray-speed-test --refresh -- Japan > results.json
jq '.results[] | {file, mbps: (.bytes_per_second * 8 / 1000000)}' results.json
```

Each candidate receives a sequential quick download with a three-second request
limit. The best three successful candidates receive sequential five-second final
downloads. Only successful final samples enter the final ranking. Fewer than
three quick successes means fewer final samples; failed finals are not replaced
with quick-only candidates. Connections time out after two seconds. The default
URL is Cloudflare's 100 MB download endpoint; `XS_TEST_URL` can override it for
ordinary command-line use. A timed-out sample is accepted only after HTTP 200,
positive downloaded bytes and at least one second of transfer time.

Successful results are cached for 600 seconds below
`$XDG_CACHE_HOME/xray-speed-test` (default `~/.cache/xray-speed-test`). The key
includes the subscription directory, candidate names and content hashes, filter,
URL and test parameters. `--refresh` bypasses reuse. Cached responses have
`cached: true`; `wall_seconds` describes the original measurement. Legacy
`speed_test.json` files are ignored. A per-cache-directory lock serializes tests
across filters. Temporary configuration files and processes are cleaned up on
normal completion and interruption; node configurations are never printed.

The version-2 JSON includes `parameters`, `created_at`, `cached`, `quick`,
`final`, `results` and `wall_seconds`. Samples contain `file`, `valid`,
`wall_seconds`, and, when available, curl status, HTTP status, bytes, download
seconds, time to first byte and bytes per second. Invalid samples include an
`error`. Empty final results produce exit status 1 and an empty ranking; callers
must check the exit status before selecting a node.

`xs` uses this same command. Fresh measurements select the best final sample;
cached calls cycle through the final ranking, containing at most three nodes.
Its filter and Nix override interfaces remain unchanged. It still changes the
active link and restarts Xray, so agents must not use it inside their sandbox.

## RPi agent transport

The agent's isolated network cannot directly probe node endpoints. On rpi5,
`xray-speed-test.service` runs the same command outside that network namespace
with `User=agent`, `Group=agent`, no new privileges, and read-only system files.
It has no write permission to the Xray configuration. Both agent and Xray
features must be enabled. No broadening of agent sandbox networking is needed.

```bash
xray-speed-test --via-worker --refresh -- Japan > results.json
```

The client atomically publishes a UUID-named JSON request under
`/home/agent/agent_work/.agent/xray-speed-test/requests/`. The request has exactly
`id` (32 lowercase hex characters), `filter` (string) and `refresh` (boolean).
The worker claims it by renaming it into `processing/`, then atomically publishes
`results/<id>.json` with the matching `id` and either `measurement` or `error`.
Only complete requests wake the path unit. No command, path, URL or timeout is
accepted from a request. Cloudflare and the packaged test parameters are fixed.

The client prints a waiting message every ten seconds and uses a bounded wait
based on candidate count plus startup, download and cleanup allowances. A timeout
never authorizes switching or reusing another request's result. Requests and
results are separate from the privileged `.agent/xray-trigger/` protocol. The
worker serializes requests, resumes claimed work after interruption, and removes
abandoned results older than a day when it next runs. Its cache lives below
`.agent/xray-speed-test/cache/`. A request queued behind other work can time out;
retry after the active test completes rather than starting competing probes.

Clients can select from `results` and use the existing `switch:<filename>`
trigger. The privileged switch helper
rejects missing files, node symlinks, paths and `active.json`, atomically replaces
the active symlink, and restores the previous link if restart fails. Successful
restart does not prove external connectivity; clients must also check egress.

## Validation and timing

```bash
python3 resource/test_xs.py
python3 resource/test_xray_update.py
bash scripts/check-configs.sh rpi5 nixos sz
```

The tests use local fake tools and do not switch production nodes. They cover
ranking, cache invalidation, errors, interruption, transport and restart rollback.

The pre-change RPi cache from 2026-10-20 contained 16 successful Japan samples,
each taking approximately 10 seconds: about 160 seconds of downloads, excluding
failed nodes and process startup. The new download budget for the same 16
candidates is 63 seconds (16 × 3 + 3 × 5), about 61% less. This is a budget,
not a measured end-to-end improvement or a guarantee of identical ranking.

After deployment, force a worker run and record candidate count, per-stage
`wall_seconds`, total wall time and downloaded bytes. Compare the final three
against isolated ten-second reference probes using the same URL and nodes,
without switching between measurements or probing concurrently. Complete one
trigger-based switch and verify its link and external connectivity. This live
acceptance requires deployment; package builds and mocked checks alone do not
establish it.
