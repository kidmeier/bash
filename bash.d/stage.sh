test -z "$JVMTI_VARIANT" && export JVMTI_VARIANT="debug"
test -z "$JVMTI_ARCH"    && export JVMTI_ARCH="IA-32"

function staging-build-env-echo() {

	echo "Build dependencies:"
	echo -e "\tJAVA_HOME=${JAVA_HOME}"
	echo -e "\tCBE_SDK_HOME=${CBE_SDK_HOME}"
	echo -e "\tTPTP_ACSDK_HOME=${TPTP_ACSDK_HOME}"
	echo -e "\tRASERVER_SDK=${RASERVER_SDK}"
	echo -e ""
	echo -e "Build settings:"
	echo -e "\tJVMTI_VARIANT=${JVMTI_VARIANT}\t(org.eclipse.tptp.platform.jvmti.runtime)"
	echo -e "\tJVMTI_ARCH=${JVMTI_ARCH}\t(org.eclipse.tptp.platform.jvmti.runtime)"
	echo -e "\tdebug=${debug}\t\t(org.eclipse.hyades.probekit)"
	echo -e "\tDEBUGABLE=${DEBUGABLE}\t(org.eclipse.tptp.platform.agentcontroller)"
	echo -e "\tFORCE32=${FORCE32}\t(org.eclipse.tptp.platform.agentcontroller)"
	echo -e "\tOPTIMIZABLE=${OPTIMIZABLE}\t(org.eclipse.tptp.platform.agentcontroller)"
	echo -e "\tRELEASE=${RELEASE}\t(org.apache.harmony_vmcore_verifier)"
	echo -e "\tSIXTYFOURBIT=${SIXTYFOURBIT}\t(org.eclipse.tptp.platform.agentcontroller)"

}

function staging-build-env-release() {

	# setup release env vars for jvmti.runtime, verifier, agentcontroller
	export JVMTI_VARIANT=release
	export RELEASE=1
	unset OPTIMIZABLE # remove this; the AC build script will configure a default

	# disable debug vars for verifier, probekit, agentcontroller
	unset DEBUG
	unset debug
	unset DEBUGABLE

}

function staging-build-env-debug() {

	# setup release env vars for jvmti.runtime, verifier, agentcontroller
	export JVMTI_VARIANT=debug
	export DEBUG=1
	export debug=1
	export DEBUGABLE="-g3"

	# disable release vars for verifier, probekit, agentcontroller
	unset RELEASE
	export OPTIMIZABLE=" "

}

function stage-probekit() {

	if [ -z "$1" -o -z "$2" ]
	then
		echo "usage: stage-probekit [source] [dest]"
		return
	else
		src="$1"
		acDest="$2"
		probekitDest="${acDest}/plugins/org.eclipse.hyades.probekit"
		jpiDest="${acDest}/plugins/org.eclipse.tptp.javaprofiler"
	fi

	[ -n "${debug}" ] && variant=Debug || variant=Release
	bciEngProbe="${src}/BCI/${variant}/BCIEngProbe.so"

	cp -f "${bciEngProbe}" "${jpiDest}/libBCIEngProbe.so"
	cp -f "${bciEngProbe}" "${probekitDest}/lib/BCIEngProbe.so"

}

function stage-jvmti() {
	
	if [ -z "$1" -o -z "$2" ]
	then
		echo "usage: stage-jvmti [source] [dest]"
		return
	else
		src="$1"
		dst="$2/plugins/org.eclipse.tptp.javaprofiler"
	fi
	
	echo "[PUSH] $src/bin/linux/$JVMTI_VARIANT/$JVMTI_ARCH/ -> $dst"
	rsync -auv "$src/bin/linux/$JVMTI_VARIANT/$JVMTI_ARCH/" "$dst"
	
	# Compile each of the java bits and cp the .class files to target
	for i in HeapAdaptor/org/eclipse/tptp/martini/HeapProxy.java \
        HeapAdaptor/org/eclipse/tptp/martini/analysis/HeapObjectData.java \
        CGAdaptor/org/eclipse/tptp/martini/CGProxy.java \
        ThreadAdaptor/org/eclipse/tptp/martini/ThreadProxy.java
	do
		dotjava="$i"
		dotclass="${i/.java/.class}"
		(echo "[JAVAC] $dotjava"; \
			javac -source 1.5 -target 1.5 "$src/src/Martini/Infrastructure/$dotjava") \
			&& \
			(echo "[CP] ${dotclass} -> $dst/${dotclass/*Adaptor\//}"; \
			cp "$src/src/Martini/Infrastructure/${dotclass}" "$dst/${dotclass/*Adaptor\//}") \
			|| return 1
	done

}

function stage-link-workspace() {

	if [ -z "$1" -o -z "$2" -o -z "$3" ]
	then
		echo "usage: stage-link-workspace [staged-ac] [workspace] [arch]"
		return
	fi

	acHome="$1"
	jpiHome="${acHome}/plugins/org.eclipse.tptp.javaprofiler"

	workspace="$2"
	arch="$3"
	jvmtiRuntime="${workspace}/org.eclipse.tptp.platform.jvmti.runtime"
	jvmtiAgentFiles="${jvmtiRuntime}/agent_files/linux_${arch}"
	iacHome="${workspace}/org.eclipse.tptp.platform.ac.linux_${arch}/agent_controller"
	probekitHome="${workspace}/org.eclipse.hyades.probekit"
	probekitVariant="`echo ${JVMTI_VARIANT:0:1} | tr 'a-z' 'A-Z'`${JVMTI_VARIANT:1}"

	case "${arch}" in
		ia32)
			probekitNative="${probekitHome}/os/linux/x86"
			;;
		em64t)
			probekitNative="${probekitHome}/os/linux/x86_64"
			;;
		*)
			echo "unknown arch: '${arch}'"
			return
			;;
	esac

	[ -d "${acHome}" ] || (echo "${acHome} is not an AC" && return)
	[ -d "${jvmtiAgentFiles}" ] || (echo "${jvmtiAgentFiles} does not exist" && return)
	[ -d "${iacHome}" ] || (echo "${iacHome} does not exist" && return)
	[ -d "${probekitHome}" ] || (echo "${probekitHome} does not exist" && return)
	[ -d "${probekitNative}" ] || (echo "${probekitNative} does not exist" && return)

	# Link stage jpi to jvmti plugin agent_files/${arch}
	if [ -L "${jvmtiAgentFiles}" ]
	then
		rm "${jvmtiAgentFiles}" || return
	else
		rmdir "${jvmtiAgentFiles}" || return
	fi
	ln -s "${jpiHome}" "${jvmtiAgentFiles}"

	# Link stage AC to IAC
	rm -f "${iacHome}/bin"      ; ln -s "${acHome}/bin" "${iacHome}/bin"
 	                              cp -r "${acHome}/config" "${iacHome}/config"
	rm -f "${iacHome}/lib"      ; ln -s "${acHome}/lib" "${iacHome}/lib"
	rm -f "${iacHome}/Resources"; ln -s "${acHome}/Resources" "${iacHome}/Resources"
	rm -f "${iacHome}/security" ; ln -s "${acHome}/security" "${iacHome}/security"

	# Link stage probekit to org.eclipse.hyades.probekit/os
	[ -L "${probekitNative}/probeinstrumenter" ] && rm -f "${probekitNative}/probeinstrumenter"
	[ -L "${probekitNative}/BCIEngProbe.so" ] && rm -f "${probekitNative}/BCIEngProbe.so"

	ln -s \
		"${probekitHome}/src-native/BCI/${probekitVariant}/probeinstrumenter" \
		"${probekitNative}/probeinstrumenter"
	ln -s \
		"${probekitHome}/src-native/BCI/${probekitVariant}/BCIEngProbe.so" \
		"${probekitNative}/BCIEngProbe.so"

	echo "${iacHome} -> ${acHome}"
	echo "${jvmtiAgentFiles} -> ${jpiHome}"
	echo "${probekitHome}/src-native/BCI/${probekitVariant} -> ${probekitNative}"

}


function stage-ac() {

	if [ -z "$1" -o -z "$2" ]
	then
		echo "usage: stage-ac [source] [dest]"
		return
	else
		src="$1"
		dst="$2"
	fi
	
	echo "[PUSH] $src/bin/ -> $dst/bin"
	rsync --exclude '*.sh' --exclude 'ChkPass' --exclude 'RAServer' --exclude 'tptpcore.jar' -av "$src/bin/" "$dst/bin"

	echo "[PUSH] $src/lib/ -> $dst/lib"
	rsync --exclude 'config.jar' --exclude 'libxerces*' -av "$src/lib/" "$dst/lib" >/dev/null

}

function build-and-stage-workspace() {
	
	if [ -z "$1" -o -z "$2" -o -z "$3" ]
	then
		echo "usage: build-and-stage-workspace [staged-ac] [workspace] [arch]"
		return
	fi

	stagedAc="$1"
	
	workspace="$2"
	vrfySrc="$workspace/org.apache.harmony_vmcore_verifier"
	acSrc="$workspace/org.eclipse.tptp.platform.agentcontroller/src-native-new"
	jvmtiSrc="$workspace/org.eclipse.tptp.platform.jvmti.runtime/src-native"
	probekitSrc="$workspace/org.eclipse.hyades.probekit/src-native"

	arch="$3"

	[ ! -d "$stagedAc" ] && echo -e "\nNo such directory: $stagedAc\n" && return
	[ ! -d "$workspace" ] && echo -e "\nNo such directory: $workspace\n" && return
	[ ! -d "$vrfySrc" ] && echo -e "\nNo such directory: $vrfySrc\n" && return
	[ ! -d "$acSrc" ] && echo -e "\nNo such directory: $acSrc\n" && return
	[ ! -d "$jvmtiSrc" ] && echo -e "\nNo such directory: $jvmtiSrc\n" && return
	[ ! -d "$probekitSrc" ] && echo -e "\nNo such directory: $probekitSrc\n" && return

	pushd "$acSrc/build" \
		&& ./build_tptp_ac.script clean \
		&& ./build_tptp_ac.script \
		&& stage-ac .. "$stagedAc" \
		&& popd \
	&& pushd "$vrfySrc/build" \
		&& make -f makefile.linux clean \
		&& make -f makefile.linux \
		&& popd \
	&& pushd "$jvmtiSrc/build" \
		&& ./build_tptp_all.script clean \
		&& ./build_tptp_all.script \
		&& stage-jvmti .. "$stagedAc" \
		&& popd \
	&& pushd "$probekitSrc" \
		&& make clean && make \
		&& stage-probekit . "$stagedAc" \
		&& popd \
	&& stage-link-workspace "$stagedAc" "$workspace" "$arch"

}

function make-ac() {

	[ -z "$SRC_AC" ] && echo "Set SRC_AC to point at the source AC" && return 1
	[ -z "$XERCESC_HOME" ] && echo "Must set XERCESC_HOME" && return 1
	[ -z "$CBE_SDK_HOME" ] && echo "Must set CBE_SDK_HOME" && return 1

	mkdir bin
	mkdir config
	mkdir lib

	cp $SRC_AC/bin/*.sh ./bin/
	cp -R $SRC_AC/plugins ./
	cp -R $SRC_AC/Resources ./
	cp -R $SRC_AC/security ./

	cp $SRC_AC/lib/config.jar ./lib
	cp $XERCESC_HOME/lib/* ./lib
	cp $CBE_SDK_HOME/lib/* ./lib

	pushd bin
	ln -s ACServer RAServer
	ln -s ACStart.sh RAStart.sh
	ln -s ACStop.sh RAStop.sh
	popd

}

