#!/bin/sh
[ -z "$(echo $- | grep i)" ] && return 0
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\# '
alias l='ls -ah --color=auto'
alias ll='ls -lsah --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ..='cd ..'
