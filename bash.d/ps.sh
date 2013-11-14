alias lsps='ps auxf|less -S'
alias lspse='ps auxef|less -S'

function lsenv() {

	if [ -z "$1" ]
	then
		echo "Usage: lsenv <PID>"
		return
	fi
	
	if [ ! -d "/proc/$1" ]
	then
		echo "PID $1 does not exist at /proc/$1"
		return
	fi

	cat "/proc/$1/environ" | tr '\0' '\n' | less

}

function lsargv() {

	if [ -z "$1" ]
	then
		echo "Usage: lsargv <PID>"
		return -1
	fi

	if [ ! -d "/proc/$1" ]
	then
		echo "PID $1 does not exist at /proc/$1"
		return -1
	fi
	
	cat "/proc/$1/cmdline" | tr '\0' ' ' | LESS="" less

}

alias @='exec-notify'
function exec-notify() {

	"$@"

	local status="$?"
	[ "0" = "$status" ] \
		&& notify-send -h "int:transient:1" "SUCCESS" "$*" \
		|| notify-send -h "int:transient:1" "FAILED" "$*"
	return "$status"

}
