test -d "$HOME/runtimes/jdks/ibm-java-i386-70" \
	&& export JAVA_HOME="$HOME/runtimes/jdks/ibm-java-i386-70" \
	&& export PATH="$JAVA_HOME/bin:$PATH"

function javacore() {

	if [ -z "$1" ]
	then
		echo "Usage: javacore <pid>"
		return 1
	fi

	kill -QUIT $1

	echo "Javacore generated in: $(readlink /proc/$1/cwd)"

}

