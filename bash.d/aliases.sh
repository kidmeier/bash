alias config='git --git-dir=/home/mike/.config.git/ --work-tree=/home/mike'

alias reverse-dns='dig +noall +answer -x'
alias edit='emacs -nw'
alias browse='nautilus --browser --no-desktop &'
alias helios='~/tools/helios/eclipse &'

alias ll='ls -alhF'
alias la='ls -A'
alias lla='ls -lhAF'
alias l='ls -CF'
alias lsps='ps auxf|less -S'
alias lspse='ps auxef|less -S'

alias where='N=0; for i in `dirs`; do  echo $N: $i; N=$((N+1)); done'
alias bt='where'
alias swap='pushd'

function fr() {

	pushd +$1

}

