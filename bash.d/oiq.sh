export OIQ_SRC="$HOME/devl/src/oiq"

export OIQ_DEPLOY="$HOME/devl/deploy"
export OIQ_HOME="$OIQ_DEPLOY/product/home"
export OIQ_CACHE="$OIQ_HOME/../../cache"
export OIQ_MINING="$OIQ_HOME/base/mining"
export OIQ_TOMCAT="$OIQ_HOME/base/tomcat"
export OIQ_UI="$OIQ_HOME/base/ui"

elProject="*[local-name()='project']"
elVersion="*[local-name()='version']"

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

export PATH="$HOME/devl/tools/jdk1.7.0_25/bin:$PATH"
export JDWP="-agentlib:jdwp=transport=dt_socket,suspend=n,address=localhost:8000,server=y"
export CATALINA_OPTS="-Dhippoecm.export.dir=$OIQ_SRC/insure-web/src/main/resources $CATALINA_OPTS"

function oiq-tomcat() {
	test -n "`tomcat-pid`" && echo "tomcat already running!?" && return 0
	"$OIQ_HOME/bin/tomcat-cache.sh"
}

function oiq-tomcat-uncached() {
	test -n "`tomcat-pid`" && echo "tomcat already running!?" && return 0
	"$OIQ_HOME/bin/tomcat.sh"
}	

function oiq-startall() {
	oiq-tomcat
}

function oiq-stop() {
	tomcat-stop
}

function oiq-stopall() {
	tomcat-stop
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
DROP DATABASE IF EXISTS std_${environment};
DROP DATABASE IF EXISTS fleet_${environment};
DROP DATABASE IF EXISTS insure_${environment};

CREATE DATABASE std_${environment} DEFAULT CHARACTER SET utf8;
CREATE DATABASE fleet_${environment} DEFAULT CHARACTER SET utf8;
CREATE DATABASE insure_${environment} DEFAULT CHARACTER SET utf8;
EOF

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
	local version="$(xmlstarlet sel -t -v "//$elProject/$elVersion/text()" ${OIQ_SRC}/pom.xml 2>/dev/null)"
	local revision=$(git "--git-dir=$OIQ_SRC/.git" rev-parse --verify HEAD)
	echo "[DEPLOY] ${version}-${revision}"

	# remove UI
	rm -rf "$OIQ_UI/app"

	# remove tomcat stuff
	rm -rf "$OIQ_TOMCAT/conf"
	rm -rf "$OIQ_TOMCAT/webapps"

	# update dist files
	unzip \
		-o \
		-u \
		-d "$OIQ_DEPLOY/product" \
		"$OIQ_SRC/${product}-dist/target/${product}-dist-${version}-product.zip"

	# force overwrite configuration files
	unzip \
		-o -d "$OIQ_DEPLOY/product" \
		"$OIQ_SRC/${product}-dist/target/${product}-dist-${version}-product.zip" \
		"home/conf/*" "home/dist/*"

	# configure
	ant -f "$OIQ_HOME/build.xml" \
		"-Doiq.install.client=${client}" \
		"-Doiq.install.type=${env}"

}

function oiq-redeploy() {
	oiq-deploy "$@" && oiq-startall
}

function oiq-clean-mvn-repo() {

	local version="$(xmlstarlet sel -t -v "//$elProject/$elVersion/text()" ${OIQ_SRC}/pom.xml 2>/dev/null)"

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

function oiq-persist-mvn-repo() {

	local repo="$HOME/.m2/repository"
	local restorefrom="$HOME/.m2/persistent-repository"
	
	rsync -acvz --delete --exclude="com/oiq/*" "${repo}/" "${restorefrom}/"

}

function oiq-umount-mvn-repo() {

	local repo="$HOME/.m2/repository"

	oiq-persist-mvn-repo \
		&& sudo umount "${repo}"

}

function oiq-cache-entry() {
	local entry="$1"; shift
	echo "$OIQ_CACHE/${entry:0:2}/${entry:2:2}/${entry}"
}

function oiq-cache-cat() {
	cat `oiq-cache-entry "$1"`
}

function oiq-cache-cat-metadata() {
	cat "`oiq-cache-entry "$1"`.json"
}

function oiq-cache-evict() {
	rm "`oiq-cache-entry "$1"`"
	rm "`oiq-cache-entry "$1"`.json"
}
