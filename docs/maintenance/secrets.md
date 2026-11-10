# Secrets and identities

Run commands from the repository root.

Secrets use agenix. Edit encrypted sources with `agenix -e`; recipient keys
remain in the local, ignored `secrets/agenix-rules.nix`. Feature modules declare their own
`age.secrets` entries and consume `config.age.secrets.<name>.path`.

The PC management key can decrypt every secret and must not be copied to servers.
RPi, HK, SZ, and WSL each use their own root-owned, mode 0600 `/etc/ssh/agenix`.
Rules authorize each active server only for files declared by its locked configuration;
shared secrets authorize all their consumers. New files default to PC-only access.

MacBook uses its existing root-owned `/etc/ssh/ssh_host_ed25519_key` through
agenix's Darwin module. Its public key authorizes only `xraysub.age`.
Mihomo waits for agenix to decrypt the subscription, including after reboot;
the decrypted file is owned by `antares:staff`, mode 0400. Never copy a private
identity between hosts. Reauthorize the subscription before replacing the Mac
SSH host key.

`xraysub.age` keeps its historical filename and supplies Mihomo on PC, RPi,
MacBook, HK and SZ. HK's recipient must be added before deploying Mihomo.
`xray-template-json.age` and `xray-template-gz.age` are encrypted recovery
archives with PC-only access; no host configuration consumes them. Disabling
or retiring a proxy does not delete encrypted sources or persistent data.

GZ will not be renewed: its key has been removed from the local rules and its
formerly authorized files rekeyed. The historical GZ configuration does not
grant recipient access.
Rekeying does not revoke old ciphertext or credentials already deployed to GZ.
Before releasing the server, remove its deployed secrets and keys; rotate shared
credentials at their providers and active consumers if old copies must be invalidated.

After changing consumers, update the rules, rekey on PC, and validate before deployment:
```bash
AGENIX_RULES=secrets/agenix-rules.nix agenix -i /etc/ssh/agenix -r
AGENIX_RULES=secrets/agenix-rules.nix agenix -c
AGE_BIN=/path/to/age bash scripts/check-agenix.sh --sz-key SZ_KEY --mac-public-key MAC_PUB ADMIN_KEY RPI_KEY HK_KEY
```
Run the script with access to local recovery keys. Do not retrieve other hosts'
private keys just to run checks; remote checks must decrypt in place and return
only success/failure. Supply `--sz-key` for the current recipient rules. Once WSL
is authorized, also pass `--wsl-key WSL_KEY`, or `--wsl-public-key WSL_PUB` to
check its recipient rules without transferring its private key. Public-key-only
checks do not verify WSL decryption; perform that check locally on WSL. An optional fourth argument points
to a pre-rekey secrets directory and verifies unchanged plaintext. Likewise,
`--mac-public-key MAC_PUB` checks MacBook recipients without retrieving its
private key; actual decryption is checked on MacBook after activation. Private keys
and plaintext must never enter Git or the Nix store. Keep recovery copies on PC.
Build HK and SZ locally with remote builders disabled, then push their closures;
build RPi on an aarch64 host. Validate actual activation using only the server key
before removing old key copies. Historical generations may require rebuilding
with current encrypted secrets before rollback.

`common/agenix.nix` owns agenix tooling, identity paths, and base account password
secrets. QQ relay and QQ Codex share the deployment in `rpi/qq-credentials.nix`;
it remains while either consumer is enabled.

WSL sets its identity path independently and only deploys
`github-sign-passphrase.age`. Its `antares.gitSignUnlock.enable` feature loads
`~antares/.ssh/github_sign` and `~antares/.ssh/github_push` into the user's
OpenSSH agent at login and when that agent restarts. The password is root-only;
the user service asks the root oneshot service to load both keys. Provision the
WSL identity and authorize its public key on PC before activating this feature.
Disabling the feature removes its services and deployed secret, preserving keys.

QQ Codex's `secrets/qq-codex-allowlist.age` keeps its historical filename but
contains the complete application TOML, including allowlists and optional
`agent_admin_qq`. `services.qq-codex-agent.configFile` references the existing
agenix secret; it is mounted at `/etc/qq-codex-private/config.toml` and is denied
to model tools. No generated application defaults are merged. Keep required
paths, shared auth socket and resource directory aligned with the application
module's mounts. Top-level fields belong before any group table declarations.
NapCat tokens and shared login credentials remain separate. Publish the updated
application and update the RPi source input before deploying this configuration.

The group cadence v3 migration replaces the three legacy per-group fields with
`observation_interval_seconds`, `message_ttl_seconds`, and
`conversation_gap_seconds`. Follow the application's
[configuration contract](https://github.com/Antares0982/qq-codex-agent/blob/main/docs/specs/configuration.md) and
[migration procedure](https://github.com/Antares0982/qq-codex-agent/blob/main/docs/internal/deployment.md#群聊节奏-v3-迁移).
Edit this encrypted TOML alongside the application change, validate it using the
new application's Settings parser, and compare parsed configurations to ensure
only cadence fields changed. Emit only validation success/failure, never group
IDs or plaintext. Keep recipients and mount permissions unchanged. New encrypted
configuration and the matching application input must deploy together; do not
activate the new configuration with an older pinned application. Rollback also
requires the matching pre-migration application database backup.

## Edit a secret

On PC, using its management key:

```bash
AGENIX_RULES=secrets/agenix-rules.nix agenix -i /etc/ssh/agenix -e <name>.age
```

## Installation staging

For `nixos-anywhere --extra-files`, explicitly set the staging directories
`etc` and `etc/ssh` to mode 0755 and the `agenix` private key to 0600; tar
preserves these directory permissions on the installed system.

Run `bash scripts/check-install-files.sh EXTRA_FILES_ROOT` before installation.
The copied tree root must also be 0755; keep its parent private (0700).

## QQ image moderation

RPi's `simple-moderation-key.age` contains only the DeepSeek API key and authorizes
PC management plus RPi identities. Its dedicated feature owns the root-only agenix
secret; the service receives it through systemd `LoadCredential`. QQ Codex does not
mount the key. Encrypt the original key file directly without printing or staging
plaintext, and validate decryption by exit status only.

The existing encrypted QQ TOML sets the top-level `moderation_url` to
`http://127.0.0.1:18765/moderate`. Keep all other parsed configuration unchanged.
Publish both application repositories before updating their RPi flake inputs and
switching on Pi. The moderation service follows QQ Codex enablement, binds only
loopback, and opens no firewall port. After activation, check both services and
submit a harmless image to the local endpoint without displaying credentials.
