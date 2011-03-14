
function identical() {

	sumA="`sha1sum $1 | cut -d' ' -f1`"
	sumB="`sha1sum $2 | cut -d' ' -f1`"
	if [ "$sumA" = "$sumB" ]
	then
		echo "yes"
	else
		echo "no"
	fi

}
