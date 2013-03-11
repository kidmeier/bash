function mvn-assert-pom() {

	if [ ! -f pom.xml ]
	then
		echo "no pom.xml found"
		return 1
	fi
	return 0

}

function mvn-enable-tests() {
	export MAVEN_OPTS=`echo $MAVEN_OPTS | sed -e "s/-Dmaven.test.skip=true//g"`
}

function mvn-disable-tests() {
	mvn-enable-tests
	export MAVEN_OPTS="-Dmaven.test.skip=true $MAVEN_OPTS"
}

function mvn-timestamp-file() {

	local goal=`test -n "$1" && echo "$1" || echo "install"`
	echo ".last-mvn-${goal}"

}

function mvn-log-file() {

	local goal=`test -n "$1" && echo "$1" || echo "install"`
	echo ".mvn-log-${goal}"

}

function mvn-clean() {
	
	for f in .last-mvn-* .mvn-log-* .mvn-resume-from
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
	local pom="${M%%/}/pom.xml"

	test -f "${pom}" || (echo "unknown module ${M}"; return 1)
	
	xpath -q -e '/project/modules/module/text() | /project/dependencies/dependency[groupId/text() = "${project.groupId}" or groupId/text() = "com.oiq"]/artifactId/text()' "${pom}"

}

function mvn-status() {

	mvn-assert-pom || return 1
	mvn-env

	local goal=`test -n "$1" && echo "$1" || echo "install"`
	local timestamp=`mvn-timestamp-file "${goal}"`
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

	local goal=`test -n "$1" && echo "$1" || echo "install"`
	local log=`mvn-log-file "${goal}"`
	local resume=".mvn-resume-from"
	local timestamp=`mvn-timestamp-file "${goal}"`
	local pl="$(mvn-status "${goal}" 2>/dev/null | sed -e 's/[[:space:]]//g')"
	local rf=""

	# resume a previously failed build?
	if [ -f "${resume}" ]
	then
		rf="-rf \":$(cat "${resume}")\""
	fi

	local status=0
	if [ -n "${pl}" ]
	then
		mvn "${goal}" -amd -pl "$pl" ${rf} | tee "${log}"
		if [ "${PIPESTATUS[0]}" = "0" ]
		then
			# record the time of our success
			date > "$timestamp"
			# next time we won't resume
			rm -f "${resume}"
		else
			# determine what failed and store into ${resume}
			egrep '\[INFO\].*FAILURE \[[0-9]+\.[0-9]+s\]$' "${log}" \
				| cut -d ' ' -f 2 > "${resume}"
			status=1
		fi
	else
		echo "Goal \"${goal}\" is up-to-date"
	fi
	return $status

}
