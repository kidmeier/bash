# define the Maven lifecycle ##################################################
declare -A MAVEN_LIFECYCLE

previous=""
for phase in \
	validate initialize \
	generate-sources process-sources generate-resources process-resources compile process-classes \
	generate-test-sources process-test-sources test-compile process-test-classes test \
	prepare-package package \
	pre-integration-test integration-test post-integration-test \
	verify install deploy
do
	MAVEN_LIFECYCLE[$phase]="${previous} ${phase}"
	previous="${previous} ${phase}"
done
unset previous
export MAVEN_LIFECYCLE

###############################################################################

function mvn-dominant-phase() {

	local -a phases=($*)

	local -i max=0
	local dom=""

	for phase in ${phases[*]}
	do

		local -a deps=(${MAVEN_LIFECYCLE[${phase}]})
		
		if (( ${#deps[*]} > ${max} ))
		then
			dom="${phase}"
			max=${#deps[*]}
		fi

	done
	echo ${dom}

}

function mvn-assert-pom() {

	if [ ! -f pom.xml ]
	then
		echo "no pom.xml found"
		return 1
	fi
	return 0

}

function mvn-enable-tests() {
	export MAVEN_OPTS=`echo $MAVEN_OPTS | sed -e "s/-DskipTests=true//g"`
}

function mvn-disable-tests() {
	mvn-enable-tests
	export MAVEN_OPTS="-DskipTests=true $MAVEN_OPTS"
}

function mvn-phase-timestamp() {

	local -a phases=(`test -n "$*" && echo $* || echo "install"`)
	local phase=`mvn-dominant-phase ${phases[*]}`
	echo ".mvn-${phase}-timestamp"

}

function mvn-phase-log() {

	local -a phases=(`test -n "$*" && echo $* || echo "install"`)
	local phase=`mvn-dominant-phase ${phases[*]}`
	echo ".mvn-${phase}-log"

}

function mvn-clean-metadata() {
	
	for f in .mvn-*
	do
		test -f "${f}" && (echo "rm ${f}"; rm "${f}")
	done

}

function mvn-env() {

	echo -e "Environment:" >&2
	echo -e "\tJAVA=\"`which java`\"" >&2
	echo -e "\tMAVEN_OPTS=\"${MAVEN_OPTS}\"" >&2

}

function mvn-dependencies() {

	local M=`test -n "$1" && echo "$1" || echo "."`
	local visited=`test -n "$2" && echo "$2" || echo ""`
	local pom="${M%%/}/pom.xml"

	test -f "${pom}" || (echo "unknown module ${M}"; return 1)
	
	local deps=""
	local children=`xpath -q -e '/project/modules/module/text() | /project/dependencies/dependency[groupId/text() = "${project.groupId}" or groupId/text() = "com.oiq" or groupId/text() = "com.oiq.data-modules"]/artifactId/text()' "${pom}" | tr -s '\n' ' '`
#	echo "${M}: ${children}" >&2
	for subM in ${children}
	do
		local seen=`echo "${visited}" | tr -s ' ' '\n' | grep "${subM}"`
		if [[ -z "${seen}" ]]
		then
			if [[ -f "${subM}/pom.xml" ]]
			then
				local subDeps=`mvn-dependencies "${subM}" "${deps}"`			
				deps="${deps} ${subDeps} ${subM}"
			elif [[ -f "data-modules/${subM}/pom.xml" ]]
			then
				local subDeps=`mvn-dependencies "data-modules/${subM}" "${deps}"`			
				deps="${deps} ${subDeps} ${subM}"
			fi
		fi
		visited="${visited} ${subM}"
	done
	echo "${deps}" | tr -s ' ' '\n' | sort | uniq

}

function mvn-status() {

	mvn-assert-pom || return 1
	mvn-env

	local -a phases=(`test -n "$*" && echo $* || echo "install"`)
	local timestamp=`mvn-phase-timestamp ${phases[*]}`
	test -f "$timestamp" || touch -t "197001010000" "$timestamp"

	local modules=`xpath -q -e '/project/modules/module/text()' pom.xml`
	local pl=""
	local changes=""

	for M in ${modules}
	do
		local moduleChanges="$(
			find "${M}" \
				-type f \
				-not -regex "${M}/.*target/.*" \
				-not -regex "${M}/\..*" \
				-newer "$timestamp"\
				|sed -e 's/\(^.*$\)/\t\1/'
			)"

		if [ -n "${moduleChanges}" ]
		then
			pl="${M},${pl}"
			changes="${changes}\n${moduleChanges}"
		fi
	done

	# remove trailing ,
	pl="${pl%%,}"

	if [ -n "${pl}" ]
	then
		echo -e "\nChanged files:" >&2
		echo -e "${changes}" >&2

		echo -e "\nProjects to rebuild:" >&2
		echo -e "\t${pl}"
	else
		echo "No changes detected!" >&2
	fi
}

function mvn-make() {
	
	mvn-assert-pom || return $?
	mvn-env

	local -a phases=(`test -n "$*" && echo $* || echo "install"`)
	local log=`mvn-phase-log ${phases[*]}`
	local resume=".mvn-resume-from"
	local timestamp=`mvn-phase-timestamp ${phases[*]}`
	local pl="$(mvn-status ${phases[*]} 2>/dev/null | sed -e 's/[[:space:]]//g')"
	local rf=""

	# resume a previously failed build?
	if [ -f "${resume}" ]
	then
		rf="-rf \":$(cat "${resume}")\""
	fi

	# clean everything if requested
	if [ -n "`echo $* | grep clean`" ]
	then
		mvn-clean-metadata
	else
		# we need to add this, otherwise old .jars hang around and everything gets fucked
		phases=(clean ${phases[*]})
	fi

	local status=0
	if [ -n "${pl}" ]
	then
		mvn ${phases[*]} -amd -pl "$pl" ${rf} | tee "${log}"
		if [ "${PIPESTATUS[0]}" = "0" ]
		then
			# record successful phases
			for phase in ${MAVEN_LIFECYCLE[`mvn-dominant-phase ${phases[*]}`]}
			do
				test -n "${phase}" && date > `mvn-phase-timestamp $phase`
			done
			# next time we won't resume
			rm -f "${resume}"
		else
			# determine what failed and store into ${resume}
			egrep '\[INFO\].*FAILURE \[[0-9]+\.[0-9]+s\]$' "${log}" \
				| cut -d ' ' -f 2 > "${resume}"
			status=1
		fi
	else
		echo "Phase \"${phases}\" is up-to-date"
	fi
	return $status

}

function mvn-noes() {

	coproc inotifywait -e close_write,move,delete,delete_self -mr "${OIQ_SRC}" 2>/dev/null
	
	trap "kill ${COPROC_PID}" INT
	while [ -d "/proc/$COPROC_PID" ]
	do 
		read -u ${COPROC[0]} dir ev file
		
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
	wait "${COPROC_PID}"

}

function mvn-server() {

	/usr/lib/jvm/java-7-openjdk-amd64/bin/java \
		"${MAVEN_OPTS}"
		-Dclassworlds.conf=/usr/share/maven/bin/m2.conf \
		-Dmaven.home=/usr/share/maven \
		-cp /usr/share/maven/boot/plexus-classworlds-2.x.jar:/usr/share/java/nailgun.jar \
		com.martiansoftware.nailgun.NGServer

}
