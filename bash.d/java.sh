
function javacore() {

	if [ -z "$1" ]
	then
		echo "Usage: javacore <pid>"
		return 1
	fi

	kill -QUIT $1

	echo "Javacore generated in: $(readlink /proc/$1/cwd)"

}

