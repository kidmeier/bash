export OIQ_SRC="$HOME/devl/src/oiq"

export OIQ_DEPLOY="$HOME/devl/deploy"
export OIQ_HOME="$OIQ_DEPLOY/product/home"
export OIQ_CACHE="$OIQ_HOME/../../cache"
export OIQ_MINING="$OIQ_HOME/base/mining"
export OIQ_TOMCAT="$OIQ_HOME/base/tomcat"

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

export PATH="$HOME/tools/jdk1.7.0_25/bin:$PATH"
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

alias activemq-pid='jps -l|grep apache-activemq|cut -d " " -f 1'
function activemq-stop() {
	
	local pid="`activemq-pid`"
	if [ -z "$pid" ]
	then
		echo "activemq not running!?"
		return 1
	fi

	echo "kill ${pid} | activemq" >&2
	kill "$pid"
   
	while [ "$pid" == "`activemq-pid`" ]
	do
		echo "waiting for activemq to exit" >&2
		sleep 1
	done

	echo "activemq is stopped" >&2
	return 0

}

function oiq-activemq() {
	test -n "`activemq-pid`" && echo "activemq already running!?" && return 0
	"$OIQ_HOME/scripts/startup/activemq.sh"
}

function oiq-tomcat() {
	test -n "`tomcat-pid`" && echo "tomcat already running!?" && return 0
	"$OIQ_HOME/bin/tomcat-cache.sh"
}

function oiq-tomcat-uncached() {
	test -n "`tomcat-pid`" && echo "tomcat already running!?" && return 0
	"$OIQ_HOME/bin/tomcat.sh"
}	

#function oiq-jmeter() {
#	test -n "`jmeter-pids`" && echo "jmeter(s) already running!?" && return 0
#	"$OIQ_HOME/scripts/startup/qaq-jmeter.sh"
#}

function oiq-startall() {
#	oiq-activemq && oiq-tomcat && oiq-jmeter
	oiq-tomcat
}

function oiq-stop() {
	tomcat-stop
#	jmeter-stopall
}

function oiq-stopall() {
	tomcat-stop
#	jmeter-stopall
#	activemq-stop
}

function oiq-restart() {
	oiq-stop && oiq-start
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

	local environment=$(test -n "$1" || echo "local" && echo "$1")

	echo -e "\n\nDROPPING schema insure_${environment}, ALL DATA WILL BE LOST\n\nContinue?"
	read pause

	cat <<EOF | mysql -u root -p
DROP DATABASE insure_${environment};
CREATE DATABASE insure_${environment} DEFAULT CHARACTER SET utf8;
EOF

}

function oiq-expire-cache() {	
	local ttl=$(test -n "$1" || echo "10080" && echo "$1")
	local cache=$(test -n "$2" || echo "$OIQ_CACHE" && echo "$2")

	echo "[OIQCACHE] ${cache} - ttl = ${ttl} minutes"
	#echo $(date --date="-${ttl} minutes"

	local count=$(find "${cache}" -type f -not -amin "+${ttl}" -print -delete | wc -l)
	echo "[OIQCACHE ${cache}] evicted ${count} entries"
}

function oiq-clean-logs() {

	for l in $OIQ_HOME/logs/*.log
	do
		echo " rm $l" && rm "$l"
	done

}

function oiq-revert-properties() {
	local product=$(test -n "$1" || echo "insure" && echo "$1")
	local client=$(test -n "$2" || echo "oiq" && echo "$2")
	local env=$(test -n "$3" || echo "local" && echo "$3")

	rm ${OIQ_HOME}/conf/oiq.properties

	ant -f "$OIQ_HOME/build.xml" \
		"-Doiq.install.client=${client}" \
		"-Doiq.install.type=${env}" \
		install-client-type
}

function oiq-deploy() {

	local product=$(test -n "$1" || echo "insure" && echo "$1")
	local client=$(test -n "$2" || echo "oiq" && echo "$2")
	local env=$(test -n "$3" || echo "local" && echo "$3")

	oiq-stop

	# determine version
	local version=$(xpath -e '/project/version/text()' $OIQ_SRC/pom.xml 2>/dev/null)
	local revision=$(git "--git-dir=$OIQ_SRC/.git" rev-parse --verify HEAD)
	echo "[DEPLOY] ${version}-${revision}"

	# remove any existing exploded wars; this will force a redeploy on the next start
	for war in $OIQ_TOMCAT/webapps/*.war
	do
		echo " rm -rf `oiq-shorten-path ${war/.war//}`"
		rm -rf "${war/.war//}"
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
		"-Doiq.install.type=${env}"

	# install UI context
	cp "$OIQ_HOME/base/ui/insure.xml" "$OIQ_HOME/base/tomcat/conf/Catalina/localhost"

}

function oiq-redeploy() {
	oiq-deploy "$@" && oiq-startall
}

function oiq-clean-mvn-repo() {

	local version=$(xpath -e '/project/version/text()' $OIQ_SRC/pom.xml 2>/dev/null)

	# remove all built artifacts
	find "${HOME}/.m2/repository/com/oiq" \
		-depth \
		-not -regex ".*/${version}-SNAPSHOT" \
		-and -regex '.*-SNAPSHOT' \
		-print \
		-exec rm -rf {} \;

	# solr cores
	local solrVersion=$(
		grep solr.cores.public.data.version \
			"$OIQ_SRC/insure-dist/src/main/resources/dist/oiq/local/oiq.properties" \
		| sed -e 's/solr\.cores\.public\.data\.version=//'
	)
	
	find "${HOME}/.m2/repository/com/oiq" \
		-type d \
		-depth \
		-not -regex ".*/${solrVersion}.*" \
		-and -regex '.*/solr-ca/.*' \
		-print \
		-exec rm -rf {} \;
}

function oiq-mount-mvn-repo() {

	local repo="$HOME/.m2/repository"
	local restorefrom="$HOME/.m2/persistent-repository"

	echo "restoring Maven ramdisk at ${repo}"

	sudo mount tmpfs "${repo}" -t tmpfs -o "user,uid=$USER,gid=$GROUP"
	rsync -avz "${restorefrom}/" "${repo}/"

}

function oiq-umount-mvn-repo() {

	local repo="$HOME/.m2/repository"
	local restorefrom="$HOME/.m2/persistent-repository"

	rsync -acvz --delete --exclude="com/oiq/*" "${repo}/" "${restorefrom}/"
	sudo umount "${repo}"

}

### Incomplete ################################################################

function oiq-smoketest() {

	oiq-stopall

}

function oiq-company-mining-log() {

	local oiqId="$1"
	local logs="$(ls -1 $OIQ_HOME/logs/mining-company.log* | sort -r)"
	local thread="$(cat $logs|grep "###oiqId=$oiqId"|sed -e 's/\(^[A-Z]* *[0-9][0-9] [a-zA-Z]* [0-9]* [0-9]*:[0-9]*:[0-9]*,[0-9]* \)\(Thread Group \)\([0-9-]* \)\(.*$\)/\3/')"

	cat $logs | grep "$thread" | less

}
