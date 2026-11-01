# Sourced by every Zsh, including noninteractive and login shells.
if [[ ${AS_WINDOWS_SHELL-} != 1 ]]; then
  # Also allow `AS_WINDOWS_SHELL=0 zsh` inside a Windows shell.
  if (( ${+_ANTARES_WS_PATH} )); then
    export PATH=$_ANTARES_WS_PATH
    if [[ -n ${_ANTARES_WS_ZOXIDE-} ]]; then
      export _ZO_DATA_DIR=$_ANTARES_WS_ZOXIDE
    else
      unset _ZO_DATA_DIR
    fi
    unset _ANTARES_WS_PATH _ANTARES_WS_ZOXIDE
  fi
  return 0
fi

if (( ! ${+_ANTARES_WS_PATH} )); then
  export _ANTARES_WS_PATH=$PATH
  export _ANTARES_WS_ZOXIDE=${_ZO_DATA_DIR-}
fi

_windows_shell_mount_root=@mountRoot@
_windows_shell_mount_root=${_windows_shell_mount_root%/}
() {
  local entry
  local -a windows_path
  # Keep inherited drive paths; never enumerate executables or probe installs.
  for entry in "${path[@]}"; do
    [[ $entry == "$_windows_shell_mount_root"/[a-zA-Z](|/*) ]] && windows_path+=("$entry")
  done
  path=('@commands@' '@native@' "${windows_path[@]}")
  typeset -gU path
  export PATH
}
export _ZO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/windows-shell/zoxide"
