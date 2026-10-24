# Zsh

`common/zsh.nix` owns the system Zsh baseline on all seven hosts, including
platform adapters, Oh My Zsh plugins, aliases, and fzf shell integration.
Linux-only aliases stay on Linux. Host configurations select prompt settings and
host-specific shell paths. PC Home Manager extensions live in
`pc/users/antares-home/zsh.nix`; environment data stays in `_env.nix`.
Oh My Zsh owns `compinit`; do not initialize it again in Home Manager.
Run `CHECK_CASE='zsh-base|starship-.*' bash scripts/check-configs.sh` for the shared checks.

## Starship

`modules/starship.nix` owns the shared prompt. Its base is
[`resource/starship.toml`](../../resource/starship.toml), adapted from Starship
1.26.0's [Gruvbox Rainbow preset](https://starship.rs/presets/gruvbox-rainbow).
Keeping the preset in the repository gives every host the same base despite
independent package versions. The preset uses Nerd Font glyphs.
Each host enables
`antares.starship.enable` and overrides `antares.starship.settings` in
`hosts/<name>/configuration.nix`; WSL uses `wsl/default.nix`.
Settings recursively override the shared defaults, preserving unspecified fields.
All [Starship settings](https://starship.rs/config/) are supported, for example:

```nix
antares.starship = {
  enable = true;
  settings = {
    palettes.host.cwd_bg = "#00af00";
    palettes.host.cwd_fg = "#000000";
    directory.truncation_length = 5;
    add_newline = false;
  };
};
```

The shared palette colors the directory and its read-only marker. PC uses green,
macbook pink, servers orange, RPi purple, and WSL blue. Purple and blue use white
text; the other backgrounds use black. The adjoining Powerline separators follow
the directory background. The remaining layout, icons, directory substitutions,
Git/language modules, clock, and prompt character follow the preset.

Nix generates `/etc/starship.toml`. Interactive Zsh always sets `STARSHIP_CONFIG`
to this file, ignoring inherited paths and home-directory configuration files.
Home Manager initializes Starship for its users (currently PC's `antares` and HK's
`alice`), without generating a separate home configuration. The system initializes
it for other users, including root. Both skip initialization for `TERM=dumb`;
noninteractive shells do not initialize the prompt.

Setting `antares.starship.enable = false` removes its package, generated file,
and initialization, leaving the ordinary Zsh prompt. Powerlevel10k is no longer
managed or loaded. Old files in user homes are left untouched.

## Formatting

`nixtreefmt` formats regular `.nix` files below the current directory using
`fd -t f -e nix -x`, with fd's default parallelism and ignore rules. It prints
only paths whose formatting changed; already formatted files produce no output.
Formatting failures retain nixfmt's diagnostics and produce a nonzero exit status.
Run `bash scripts/test-nixtreefmt.sh` to check changed, unchanged, and invalid files.
