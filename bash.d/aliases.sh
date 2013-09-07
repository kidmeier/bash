alias config='git --git-dir=/home/mike/.config.git/ --work-tree=/home/mike'

# misc
alias reverse-dns='dig +noall +answer -x'
alias edit='emacs -nw'
alias browse='nautilus --browser --no-desktop &'
alias gmake='make'
alias debug='gdb --args'

# ls
alias ll='ls -alhF'
alias la='ls -A'
alias lla='ls -lhAF'
alias l='ls -CF'

alias df='df -h'

# Directory stack 
alias pd='pushd'
alias where='N=0; for i in `dirs`; do  echo $N: $i; N=$((N+1)); done'
alias bt='where'
alias swap='pushd'

function fr() {

	pushd +$1

}

alias engage='play -c2 -n synth whitenoise band -n 100 24 band -n 300 100 gain +20'
alias sync-music='rsync -avz ./ case@wintermute:~/music/'
