# Explicit pipelines keep Windows fzf from executing Linux shell strings.
_windows_shell_fzf() {
  WSLENV="${WSLENV:+$WSLENV:}FZF_DEFAULT_COMMAND:FZF_DEFAULT_OPTS:FZF_DEFAULT_OPTS_FILE" \
    FZF_DEFAULT_COMMAND='' FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' \
    command fzf --height=40% --layout=reverse --bind=ctrl-z:ignore "$@"
}

_windows_shell_files() {
  # A successful early selection can close the producer's pipe (SIGPIPE).
  # The selector's exit status decides whether to insert the selection.
  setopt localoptions no_pipefail no_aliases
  local selected item insertion=''
  selected=$(command rg --files --hidden --glob '!.git' --path-separator / --null |
    _windows_shell_fzf --read0 --print0 --multi --scheme=path) || return 0
  for item in "${(@0)selected}"; do
    [[ -n $item ]] && insertion+="${(q)item} "
  done
  LBUFFER+=$insertion
  zle reset-prompt
}

_windows_shell_directories() {
  setopt localoptions no_aliases
  local selected dir
  selected=$(_windows_shell_fzf --walker=dir,hidden \
    --walker-skip=.git,node_modules,.venv,target --scheme=path \
    --print0 --no-multi < /dev/tty) || return 0
  dir=${selected%$'\0'}
  [[ -n $dir ]] || return 0
  # The walker returns paths relative to its Windows working directory.
  dir=${dir//\\//}
  builtin cd -- "$dir" || return
  zle reset-prompt
}

_windows_shell_history() {
  setopt localoptions no_pipefail no_aliases
  # Oh My Zsh may have loaded only selected features of this module already.
  zmodload -F zsh/parameter p:history
  local selected event
  selected=$(
    for event in ${(Onk)history}; do
      printf '%s\t%s\0' "$event" "${history[$event]}"
    done | _windows_shell_fzf --read0 --print0 --no-multi --no-sort \
      --scheme=history --delimiter=$'\t' --with-nth=2.. --query="$LBUFFER"
  ) || return 0
  [[ -n $selected ]] || return 0
  selected=${selected%$'\0'}
  BUFFER=${selected#*$'\t'}
  CURSOR=${#BUFFER}
  zle reset-prompt
}

if [[ $TERM != dumb ]]; then
  zle -N _windows_shell_files
  zle -N _windows_shell_directories
  zle -N _windows_shell_history
  for _windows_shell_keymap in emacs viins vicmd; do
    bindkey -M $_windows_shell_keymap '^T' _windows_shell_files
    bindkey -M $_windows_shell_keymap '\ec' _windows_shell_directories
    bindkey -M $_windows_shell_keymap '^R' _windows_shell_history
  done
  unset _windows_shell_keymap
fi

if [[ @starshipEnabled@ == 1 ]]; then
  _windows_shell_prompt_config() {
    if [[ $PWD == "$_windows_shell_mount_root"/[a-zA-Z](|/*) ]]; then
      export STARSHIP_CONFIG='@gitPrompt@'
    else
      export STARSHIP_CONFIG='@plainPrompt@'
    fi
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _windows_shell_prompt_config
  _windows_shell_prompt_config
fi
