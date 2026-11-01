# Zsh

`common/zsh.nix` owns the system Zsh baseline on all seven hosts, including
platform adapters, Oh My Zsh plugins, aliases, and fzf shell integration.
Linux-only aliases stay on Linux. Host configurations select prompt settings and
host-specific shell paths. PC Home Manager extensions live in
`pc/users/antares-home/zsh.nix`; environment data stays in `_env.nix`.
Oh My Zsh owns `compinit`; do not initialize it again in Home Manager.
Run `CHECK_CASE='zsh-base|starship-.*' bash scripts/check-configs.sh` for the shared checks.

The `ctl`/`sctl` and `jtl`/`sjtl` alias families are shared by all six Linux
hosts. macOS does not define these systemd aliases.

## WSL as a Windows shell

WSL enables `antares.windowsShell.enable` in `wsl/default.nix`. The feature lives
in `modules/windows-shell.nix`; its shell code is in `resource/windows-shell/`.
It activates only when `AS_WINDOWS_SHELL=1`. For example, use this Windows
Terminal profile command line (replace `NixOS` with the registered distro name):

```text
wsl.exe -d NixOS --exec bash -c "AS_WINDOWS_SHELL=1 exec zsh"
```

Set the Terminal profile's starting directory to the desired Windows project
directory. The shell does not automatically change directory. Install and select
**FiraCode Nerd Font Mono** in the Windows Terminal profile for the icons;
installing fonts only inside NixOS does not configure Windows Terminal.

### Windows CLI prerequisites

Install these on Windows and put their executables on the **Windows PATH**.
The profile has fixed launchers, not installation discovery or Linux fallbacks.
Missing tools fail when invoked. Reopen Windows Terminal after changing PATH;
an existing WSL shell retains its old environment. In particular, WinGet's
`%LOCALAPPDATA%\Microsoft\WinGet\Links` and installer-specific bin directories
must be available to the new WSL session. The Windows drive mount root comes
from `wsl.wslConf.automount.root` (normally `/mnt`).

| Commands in Zsh | Assumed Windows commands / installation |
|---|---|
| `git`, `gh` | `git.exe`, `gh.exe` (Git for Windows, GitHub CLI) |
| `uv`, `uvx` | `uv.exe`, `uvx.exe` |
| `python`, `python3` | Both use the actual Python installation's `python.exe`, not a Store placeholder |
| `rg`, `fd`, `fzf` | `rg.exe`, `fd.exe`, `fzf.exe` |
| `eza`, `nvim`, `delta`, `jq` | Corresponding `.exe` commands |
| `yazi`, `ya` | `yazi.exe`, `ya.exe` |
| `7z` | `7z.exe` from the full 7-Zip installation; add its directory to PATH |
| `ffmpeg`, `ffprobe`, `magick` | FFmpeg and ImageMagick `.exe` commands |
| `node` | `node.exe` |
| `npm`, `npx` | Windows Node with bundled `node_modules/npm/bin/{npm,npx}-cli.js` beside `node.exe` |
| `ruff` | `ruff.exe`, for example installed by Windows `uv tool install ruff` |
| `winget`, `explorer`, `clip`, `cmd`, `powershell`, `pwsh`, `wt` | Corresponding Windows `.exe` commands; `pwsh` requires PowerShell 7 |

Windows **Starship** (`starship.exe`) is also assumed installed for Git status.
Windows Yazi's additional dependencies are separate from the shell's command
mapping: Windows zoxide, Poppler for PDF previews, and Git for Windows' `file.exe`.
Set Windows `YAZI_FILE_ONE` to that executable, normally
`C:\Program Files\Git\usr\bin\file.exe`. See the
[Yazi Windows installation guide](https://yazi-rs.github.io/docs/installation/#windows).

`shfmt`, `stylua`, `codex`, `opencode`, and additional compiler/development tools
are not exposed by this profile. To add a Windows CLI, add its name to the fixed
`commands` mapping in `modules/windows-shell.nix`, update this table, and install
the Windows tool. No startup-time executable scan or availability check is used.
The npm/npx launchers resolve Node when called and invoke its JS entry point
directly, without a general-purpose CMD quoting layer.

### Command routing and Linux tools

PATH contains the Windows launchers, a dedicated Linux tool directory, and
inherited Windows drive directories, in that order. Complete Nix system/user
profile bin directories are excluded. Launchers forward arguments, standard
input and exit status without converting user paths. Linux child processes
using the inherited PATH see the same launchers; Windows processes use their
Windows environment. Absolute executable paths and programs that replace PATH
are outside this routing policy.

The Linux tool directory exposes Bash/Zsh, coreutils, grep/sed/awk, less, bat,
zoxide, file, ncurses/hostname/glibc utilities, Nix, nixos-rebuild, systemd,
procps, OpenSSH, wslpath and the NixOS sudo wrapper. Linux Starship renders the
prompt. `cat` continues to use bat. Shared systemd aliases remain available;
`nixtreefmt` is omitted because its implementation pins Linux file traversal.

Use `linux-shell` for a nested ordinary Zsh, or `linux-shell <command> [args...]`
for a single command with the original Linux PATH. `exit` returns from the
nested shell. `AS_WINDOWS_SHELL=0 zsh` also restores the ordinary mode.
Nix development environments may deliberately replace PATH; use `linux-shell`
when working with a Linux devShell.

### Independent state and interactive behavior

Windows-mode state stays on the WSL filesystem:

| State | Location (respects the corresponding XDG variable) |
|---|---|
| Zsh history | `$XDG_STATE_HOME/windows-shell/zsh_history`, default `~/.local/state/windows-shell/zsh_history` |
| Linux zoxide database | `$XDG_DATA_HOME/windows-shell/zoxide`, default `~/.local/share/windows-shell/zoxide` |
| Oh My Zsh and completion cache | `$XDG_CACHE_HOME/windows-shell/oh-my-zsh`, default `~/.cache/windows-shell/oh-my-zsh` |

No ordinary-mode history or directory visits are imported. Windows-mode sessions
share their own history with each other. `z` and `zi` use Linux zoxide with this
dedicated database; Windows Yazi uses its own Windows zoxide database. Disabling
the feature removes declarations and leaves all saved data intact.

- **Ctrl-T:** `rg.exe --files` supplies files to `fzf.exe`; selected paths are
  quoted and inserted without executing the command. Hidden files are included,
  `.git` is excluded, and ripgrep's ignore rules apply.
- **Alt-C:** Windows fzf traverses directories, including empty ones, and Zsh
  enters the selected directory. It skips `.git`, `node_modules`, `.venv`, and
  `target`; this is a fixed skip list, not ripgrep's ignore handling.
- **Ctrl-R:** Windows fzf selects from this mode's Zsh history without executing
  the selection. Multiline commands are preserved.

Cancelling leaves input and directory unchanged. These widgets have no preview
or reload commands. Standard Zsh completion remains; the Oh My Zsh fzf plugin
and its `**` fuzzy completion are not loaded in Windows mode. `TERM=dumb` skips
interactive key bindings and prompt initialization.

The prompt shows a fixed Windows icon on blue (`#0078D4`), an abbreviated path,
and the input marker. It does not perform language/project detection, directory
permission checks or Git-root-based path truncation. On Windows drive paths,
`git_status.windows_starship` delegates status to `starship.exe`; Linux Starship
still does the small initial repository lookup. On Linux paths, Git status is
disabled. A fixed launcher prevents missing Windows Starship from falling back
to Linux Git status. The generated configurations are exposed under
`/etc/windows-shell/starship{,-git}.toml`.

Run `bash scripts/check-configs.sh wsl` for module ownership and enable/disable
checks, and `bash scripts/test-windows-shell.sh` for routing, state isolation and
picker behavior. The latter builds only the profile, uses temporary HOME/data
directories and mock Windows executables, and never switches the system.
For a real WSL session, also check the installed Windows tools and interactive
key bindings after opening a terminal with the updated Windows PATH.

## Directory selection

All hosts use zoxide instead of the Oh My Zsh `z` plugin. `z` jumps by directory
history and `zi` opens its fzf selector. New visits populate the zoxide database;
existing Oh My Zsh history is not imported automatically.

On PC, `zn`, `zc`, and `zo` open that selector, then run Neovim, Codex, or
OpenCode in the selected directory through `_f`, preserving devShell handling.
Optional keywords narrow the candidates, e.g. `zc nix`. Cancelling leaves the
current directory unchanged and starts nothing. Run
`bash scripts/test-zsh-jump.sh` to check selection, argument forwarding, and
cancellation.

## Direnv

PC (`hosts/nixos/configuration.nix`) and WSL (`wsl/default.nix`) explicitly set
`programs.direnv.enable = false`. Set it to `true` to install direnv and enable
the native NixOS shell integration, including Zsh and nix-direnv. No separate
package entry or Home Manager hook is needed. Existing user files are preserved.
Run `CHECK_CASE='direnv-.*' bash scripts/check-configs.sh nixos wsl` to check
the disabled configuration and re-enabling it.

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
Powerline separators. PC and WSL use green, macbook pink, servers orange, and RPi
purple. All use the preset's off-white `color_fg0` (`#fbf1c7`) text.
The directory and its read-only marker use the preset's yellow background
(`color_yellow`, `#d79921`) and off-white text. The remaining layout, icons,
Git/language modules, clock, and prompt character follow the preset.

Nix generates `/etc/starship.toml`. Ordinary interactive Zsh sets `STARSHIP_CONFIG`
to this file, ignoring inherited paths and home-directory configuration files.
The opt-in WSL Windows mode selects its separate generated configuration instead.
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
