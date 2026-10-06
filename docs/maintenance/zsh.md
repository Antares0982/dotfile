# Zsh

`common/zsh.nix` owns the system Zsh baseline on all seven hosts, including
platform adapters, Oh My Zsh plugins, aliases, and fzf shell integration.
Linux-only aliases stay on Linux. Host configurations select prompt files and
host-specific shell paths. PC Home Manager extensions live in
`pc/users/antares-home/zsh.nix`; environment data stays in `_env.nix`.
Oh My Zsh owns `compinit`; do not initialize it again in Home Manager.
Run `CHECK_CASE=zsh-base bash scripts/check-configs.sh` for the shared checks.
