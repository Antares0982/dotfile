# Secrets and identities

Run commands from the repository root.

Secrets use agenix. Edit encrypted sources with `agenix -e`; recipient keys
remain in the local, ignored `secrets/agenix-rules.nix`. Feature modules declare their own
`age.secrets` entries and consume `config.age.secrets.<name>.path`.

The PC management key can decrypt every secret and must not be copied to servers.
RPi, HK, and GZ each use their own root-owned, mode 0600 `/etc/ssh/agenix`.
Rules authorize each server only for files declared by its locked configuration;
shared secrets authorize all their consumers. New files default to PC-only access.
After changing consumers, update the rules, rekey on PC, and validate before deployment:
```bash
AGENIX_RULES=secrets/agenix-rules.nix agenix -i /etc/ssh/agenix -r
AGENIX_RULES=secrets/agenix-rules.nix agenix -c
AGE_BIN=/path/to/age bash scripts/check-agenix.sh ADMIN_KEY RPI_KEY HK_KEY GZ_KEY
```
Run the script with access to the private keys. An optional fifth argument points
to a pre-rekey secrets directory and verifies unchanged plaintext. Private keys
and plaintext must never enter Git or the Nix store. Keep recovery copies on PC.
Build HK and GZ locally with remote builders disabled, then push their closures;
build RPi on an aarch64 host. Validate actual activation using only the server key
before removing old key copies. Historical generations may require rebuilding
with current encrypted secrets before rollback.

`common/agenix.nix` owns agenix tooling, identity paths, and base account password
secrets. QQ relay and QQ Codex share the deployment in `rpi/qq-credentials.nix`;
it remains while either consumer is enabled.

## Edit a secret

On PC, using its management key:

```bash
AGENIX_RULES=secrets/agenix-rules.nix agenix -i /etc/ssh/agenix -e <name>.age
```

## Installation staging

For `nixos-anywhere --extra-files`, explicitly set the staging directories
`etc` and `etc/ssh` to mode 0755 and the `agenix` private key to 0600; tar
preserves these directory permissions on the installed system.
