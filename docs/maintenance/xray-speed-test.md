# Xray speed tests

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

The deployable skill is in `.agents/skills/xray-switch/SKILL.md`; install that file
at the same relative location in the agent workspace. It selects from `results`
and uses the existing `switch:<filename>` trigger. The privileged switch helper
rejects missing files, node symlinks, paths and `active.json`, atomically replaces
the active symlink, and restores the previous link if restart fails. Successful
restart does not prove external connectivity, so the skill also checks egress.

## Validation and timing

```bash
python3 resource/test_xs.py
python3 resource/test_xray_update.py
bash scripts/check-configs.sh rpi5 nixos gz sz
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
skill-driven switch and verify its link and external connectivity. This live
acceptance requires deployment; package builds and mocked checks alone do not
establish it.
