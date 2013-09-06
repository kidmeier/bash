[ -n "${MAVEN_LOCAL_REPO}" ] || export MAVEN_LOCAL_REPO="$HOME/.m2/repository"

# Xpath helpers ###############################################################

elGroupId="*[local-name()='groupId']"
elModule="*[local-name()='module']"
elModules="*[local-name()='modules']"
elPackaging="*[local-name()='packaging']"
elProfile="*[local-name()='profile']"
elProfiles="*[local-name()='profiles']"
elProject="*[local-name()='project']"
elParent="*[local-name()='parent']"
elVersion="*[local-name()='version']"

###############################################################################

function _mkn-assert-pom() {

	if [ ! -f pom.xml ]
	then
		echo "no pom.xml found"
		return 1
	fi
	return 0

}

function mkn-enable-tests() {
	export MAVEN_OPTS=`echo $MAVEN_OPTS | sed -e "s/-DskipTests=true//g"`
}

function mkn-disable-tests() {
	mkn-enable-tests
	export MAVEN_OPTS="-DskipTests=true $MAVEN_OPTS"
}

function mkn-env() {

	echo -e "Environment:" >&2
	echo -e "\tJAVA=\"`which java`\"" >&2
	echo -e "\tMAVEN_OPTS=\"${MAVEN_OPTS}\"" >&2

}

function _mkn-list-modules() {

	local parent="${1:-.}"; shift
	local modules="$(xmlstarlet sel -t -v "//$elModules/$elModule/text()" ${parent}/pom.xml 2>/dev/null)"
	for m in ${modules}
	do
		local subModules="`_mkn-list-modules ${parent}/${m}`"
		for _m in ${subModules}
		do
			modules="${modules} ${m}/${_m}"
		done
	done

	echo "${modules}" | tr ' ' '\n' | sort | uniq
	
}

# return 0 (success) if module has changed
function _mkn-module-changed() {

	local M="${1%/}"; shift
	local m="`basename ${M}`"

	[ -z "${M}" ] \
		&& echo "_mkn-module-changed: must specify module" >&2 \
		&& return 1

	local -a phases=(`test -n "$*" && echo $* || echo "install"`)

	local groupId="$(xmlstarlet sel -t -v "/$elProject/$elParent/$elGroupId/text()" ${M}/pom.xml 2>/dev/null)"
	local version="$(xmlstarlet sel -t -v "/$elProject/$elParent/$elVersion/text()" ${M}/pom.xml 2>/dev/null)"
	local packaging="$(xmlstarlet sel -t -v "/$elProject/$elPackaging/text()" ${M}/pom.xml 2>/dev/null)"
	local dist="${m}-${version}.${packaging:-jar}"
	local timestamp="${M}/target/${dist}"
	local repoArtifact="${MAVEN_LOCAL_REPO}/${groupId//.//}/${m}/${version}/${dist}"

	[ ! -e "${timestamp}" ] && [ "pom" = "${packaging}" ] && return 1
	[ ! -e "${timestamp}" ] && return 0
	[ ! -e "${repoArtifact}" ] && return 0

	local changedFiles="$(
			find "${M}" \
				-type f \
				-not -regex "${M}/.*target/.*" \
				-not -regex "${M}/\..*" \
				-newer "$timestamp"
			)"

	test -e "${repoArtifact}" || return 0
	test -n "${changedFiles}"

}

function mkn-status() {

	_mkn-assert-pom || return 1
	mkn-env

	local modules="`_mkn-list-modules`"
	local pl=""

	for M in ${modules}
	do
		_mkn-module-changed "${M}" && pl="${M},${pl}"
	done

	# remove trailing ,
	pl="${pl%%,}"

	if [ -n "${pl}" ]
	then
		echo -e "\nTargets:" >&2
		echo -e "\t${pl}"
	else
		echo "All targets are up to date" >&2
	fi
}

function mkn() {
	
	_mkn-assert-pom || return $?
	mkn-env

	local log="/tmp/mkn-log"
	local pl="$(mkn-status 2>/dev/null | sed -e 's/[[:space:]]//g')"

	local rc=0
	if [ -n "${pl}" ]
	then
		echo "Building targets ${pl/,/, /}" >&2
		mvn clean install "$@" -o -amd -pl "$pl" | tee "${log}"
		rc="${PIPESTATUS[0]}"
	fi

	[ "0" = "${rc}" ] \
		&& echo "All targets up to date" >&2 \
		|| less "${log}"
	return ${rc}

}

function mkn-noes() {

	coproc INOTIFY (inotifywait -e close_write,move,delete,delete_self -mr "${OIQ_SRC}" 2>/dev/null)
	
	trap "kill ${INOTIFY_PID}" INT
	while [ -d "/proc/${INOTIFY_PID}" ]
	do 
		read -u ${INOTIFY[0]} dir ev file
		
		dir="$(echo ${dir} | sed -e "s:${PWD}/\?::")"

		if [ -n "${dir}" -a -n "`echo ${dir}|grep '\(src\)\|\(pom.xml\)'`" ]
		then
			# find module
			local module="${dir}"
			until [ -f "${module}/pom.xml" -o "${module}" = "." ]
			do
				module=`dirname "${module}"`
			done
			
			echo "\`${module}' needs to be rebuilt (${dir}${file})"
		fi

	done
	wait "${INOTIFY_PID}"

}

function mkn-server() {

	/usr/lib/jvm/java-7-openjdk-amd64/bin/java \
		"${MAVEN_OPTS}"
		-Dclassworlds.conf=/usr/share/maven/bin/m2.conf \
		-Dmaven.home=/usr/share/maven \
		-cp /usr/share/maven/boot/plexus-classworlds-2.x.jar:/usr/share/java/nailgun.jar \
		com.martiansoftware.nailgun.NGServer

}
