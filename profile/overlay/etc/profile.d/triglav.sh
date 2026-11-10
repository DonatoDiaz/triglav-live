# Triglav Live shell environment.
if [[ -n "${BASH_VERSION:-}" ]]; then
  if [[ -t 1 ]]; then
    PS1='\[\e[38;5;141m\]triglav\[\e[0m\] \[\e[38;5;103m\]\w\[\e[0m\] \[\e[38;5;99m\]❯\[\e[0m\] '
  fi
  alias ll='ls -lah --color=auto'
  alias d='triglav-doctor'
  alias fix='triglav-repair'
  alias mnt='triglav-mount'
  alias ask='triglav-ask'
  alias net='triglav-net'
  alias ai='triglav-ai-setup'
  export EDITOR=nano
  export PAGER=less
  export TG_VERSION="${TG_VERSION:-0.1.0}"
fi
