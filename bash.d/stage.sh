test -z "$JVMTI_VARIANT" && export JVMTI_VARIANT="debug"
test -z "$JVMTI_ARCH"    && export JVMTI_ARCH="IA-32"

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
#	agentExt="${src}/ProbeAgentExtension/ProbeAgentExtension.so"

	cp -f "${bciEngProbe}" "${jpiDest}/libBCIEngProbe.so"
	cp -f "${bciEngProbe}" "${probekitDest}/lib/BCIEngProbe.so"
#	cp -f "${agentExt}" "${probekitDest}/lib/ProbeAgentExtension.so"

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

	[ -d "${acHome}" ] || (echo "${acHome} is not an AC" && return)
	[ -d "${jvmtiAgentFiles}" ] || (echo "${jvmtiAgentFiles} does not exist" && return)
	[ -d "${iacHome}" ] || (echo "${iacHome} does not exist" && return)

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

	echo "${iacHome} -> ${acHome}"
	echo "${jvmtiAgentFiles} -> ${jpiHome}"

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

