alias tomcat-pid='jps -l|grep org.apache.catalina.startup.Bootstrap|cut -d " " -f1'
function tomcat-stop() {

	local pid="`tomcat-pid`"
	if [ -z "$pid" ]
	then
		echo "tomcat is not running!?" >&2
		return 1
	fi

	echo "kill ${pid} | tomcat" >&2
	kill "$pid"

	while [ "$pid" == "`tomcat-pid`" ]
	do
		echo "waiting for tomcat to exit" >&2
		sleep 1
	done

	echo "tomcat is stopped" >&2
	return 0

}

