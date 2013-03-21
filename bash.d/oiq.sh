export OIQ_SRC="$HOME/devl/src/oiq"

export OIQ_DEPLOY="$HOME/devl/deploy"
export OIQ_HOME="$OIQ_DEPLOY/product/home"
export OIQ_MINING="$OIQ_HOME/bin/mining"
export OIQ_TOMCAT="$OIQ_HOME/bin/tomcat"

function oiq-shorten-path() {
	test -n "$1" || (echo "usage: oiq-shorten-path <path>" && return 1)
	local path="$1"

	path=`echo $path|sed -e "s:$OIQ_TOMCAT:\\$OIQ_TOMCAT:g"`
	path=`echo $path|sed -e "s:$OIQ_MINING:\\$OIQ_MINING:g"`
	path=`echo $path|sed -e "s:$OIQ_HOME:\\$OIQ_HOME:g"`
	path=`echo $path|sed -e "s:$OIQ_DEPLOY:\\$OIQ_DEPLOY:g"`
	path=`echo $path|sed -e "s:$OIQ_SRC:\\$OIQ_SRC:g"`

	echo "$path"
}

export PATH="$HOME/tools/jdk1.6.0_38/bin:$PATH"
export JDWP="-agentlib:jdwp=transport=dt_socket,suspend=n,address=localhost:8000,server=y"
export CATALINA_OPTS="-Dhippoecm.export.dir=$OIQ_SRC/insure-web/src/main/resources $CATALINA_OPTS"

alias jmeter-pids='jps -l|grep ApacheJMeter.jar|cut -d " " -f 1'
function jmeter-stopall() {
	for p in `jmeter-pids`
	do
		local pid_jmx="$(jmeter-jmx $p)"
		local pid="$(echo $pid_jmx|sed -e 's/\([0-9]*\)\( | \)\(.*$\)/\1/')"
		local jmx="$(echo $pid_jmx|sed -e 's/\([0-9]*\)\( | \)\(.*$\)/\3/')"

		echo "kill $pid | $jmx" && kill "$pid"
	done
}

function jmeter-ls() {
	for p in `jmeter-pids`
	do 
		echo `jmeter-jmx "$p"`
	done
}

function jmeter-jmx() {
	test -n "$1" || (echo "usage: jmeter-jmx <pid>" && return 1)
	local pid="$1"

	if [ -f "/proc/$pid/cmdline" ]
	then
		echo "$pid | \"$(oiq-shorten-path "`cat /proc/$pid/cmdline | tr '\0' '\n' | grep \.jmx\$`")\""
	else
		echo "no such process: $pid"
		return 2
	fi
}

function oiq-activemq() {
	test -n "`activemq-pid`" && echo "activemq already running!?" && return 0
	"$OIQ_HOME/scripts/startup/activemq.sh"
}

function oiq-tomcat() {
	test -n "`tomcat-pid`" && echo "tomcat already running!?" && return 0
	"$OIQ_HOME/scripts/startup/tomcat.sh"
}

function oiq-jmeter() {
	test -n "`jmeter-pids`" && echo "jmeter(s) already running!?" && return 0
	"$OIQ_HOME/scripts/startup/jmeter.sh"
}

function oiq-startall() {
	oiq-activemq && oiq-tomcat && oiq-jmeter
}

function oiq-stopall() {
	tomcat-stop
	jmeter-stopall
}

function oiq-env() {
	echo "export OIQ_DEPLOY=\"${OIQ_DEPLOY}\""
	echo "export OIQ_HOME=\"${OIQ_HOME}\""
	echo "export OIQ_SRC=\"${OIQ_SRC}\""
	echo "export OIQ_TOMCAT=\"${OIQ_TOMCAT}\""
	echo "export OIQ_MINING=\"${OIQ_MINING}\""
	echo "export CATALINA_OPTS=\"${CATALINA_OPTS}\""
	echo "export MAVEN_OPTS=\"${MAVEN_OPTS}\""
}

function oiq-disable-debug() {
	export CATALINA_OPTS=`echo $CATALINA_OPTS | sed -e "s/${JDWP}//g"`
	export MAVEN_OPTS=`echo $MAVEN_OPTS | sed -e "s/-Dproguard.skip=true//g"`

	oiq-env
}

function oiq-enable-debug() {
	oiq-disable-debug

	export CATALINA_OPTS="${JDWP} ${CATALINA_OPTS}"
	# Because Proguard binaries are not debugger friendly
	export MAVEN_OPTS="-Dproguard.skip=true $MAVEN_OPTS"

	oiq-env
}

function oiq-clean-db() {

	cat <<EOF | mysql -u root -p
DROP DATABASE fleet_local;
DROP DATABASE insure_local;
DROP DATABASE life_local;
DROP DATABASE people_local;

CREATE DATABASE fleet_local DEFAULT CHARACTER SET utf8;
CREATE DATABASE insure_local DEFAULT CHARACTER SET utf8;
CREATE DATABASE life_local DEFAULT CHARACTER SET utf8;
CREATE DATABASE people_local DEFAULT CHARACTER SET utf8;
EOF

}

function oiq-clean-logs() {

	for l in $OIQ_HOME/logs/*.log
	do
		echo " rm $l" && rm "$l"
	done

}

function oiq-deploy() {

	local product=$(test -n "$1" || echo "insure" && echo "$1")
	local client=$(test -n "$2" || echo "oiq" && echo "$2")
	local env=$(test -n "$3" || echo "local" && echo "$3")

	tomcat-stop

	# determine version
	local version=$(xpath -e '/project/version/text()' $OIQ_SRC/pom.xml 2>/dev/null)
	echo "[DEPLOY] ${version}"

	# remove any existing exploded wars; this will force a redeploy on the next start
	for war in $OIQ_TOMCAT/webapps/*.war
	do
		echo " rm -rf `oiq-shorten-path ${war/.war//}`"
		rm -rf "${war/.war//}"
	done

	# cleanup artifacts from other versions
	for jar in `find "$OIQ_HOME/bin" -iname '*.jar' | grep "${version/-SNAPSHOT}"`
	do 
		echo " rm $(oiq-shorten-path "$jar")"
		rm "$jar"
	done

	# unzip the dist
	unzip \
		-u \
		-o \
		-d "$OIQ_DEPLOY/product" \
		-x "$OIQ_SRC/${product}-dist/target/${product}-dist-${version}-product.zip"

	# configure
	ant -f "$OIQ_HOME/build.xml" \
		"-Doiq.install.client=${client}" \
		"-Doiq.install.type=${env}" \
		"setup-web" \
		"setup-mining" \
		"setup-web"

	# start tomcat
	"$OIQ_HOME/scripts/startup/tomcat.sh"

}

