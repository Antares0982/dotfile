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
    palettes.host.color_os = "#00af00";
    directory.truncation_length = 5;
    add_newline = false;
  };
};
```

`palettes.host.color_os` colors the OS/username segment and its adjoining
Powerline separators. PC uses green, macbook pink, servers orange, RPi purple,
and WSL blue. All use the preset's off-white `color_fg0` (`#fbf1c7`) text.
The directory and its read-only marker use the preset's yellow background
(`color_yellow`, `#d79921`) and off-white text. The remaining layout, icons,
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

### Directory paths

All hosts use `fish_style_pwd_dir_length = 1` and `home_symbol = "~"`.
Parents that would otherwise be omitted are abbreviated to their first
character; the home directory appears as `~`. For example, the repository
`~/Documents/GitHub/Nix` appears as `~/D/G/Nix`.

`truncation_length = 3` and Starship's default `truncate_to_repo = true`
determine which trailing components remain unabbreviated. To keep two
characters per abbreviated parent instead, set a host override:

```nix
antares.starship.settings.directory = {
  fish_style_pwd_dir_length = 2;
};
```

The preset's directory icon substitutions are removed because nonempty
`substitutions` disable Fish-style abbreviation. See the
[directory options](https://starship.rs/config/#directory).

## Formatting

`nixtreefmt` formats regular `.nix` files below the current directory using
`fd -t f -e nix -x`, with fd's default parallelism and ignore rules. It prints
only paths whose formatting changed; already formatted files produce no output.
Formatting failures retain nixfmt's diagnostics and produce a nonzero exit status.
Run `bash scripts/test-nixtreefmt.sh` to check changed, unchanged, and invalid files.
