function push-stage() {

    if [ -n "$1" ]
    then
        src="$1"
        shift
    else
        src="$PWD"
    fi

    if [ -n "$1" ]
    then
        dst="$1"
    else
        dst=$HOME/devl/tptp/stage
    fi

	echo "[PUSH] $src/bin/ -> $dst/bin"
    rsync -C --delete --exclude '*.sh' --exclude 'RAServer' --exclude 'tptpcore.jar' -auv "$src/bin/" "$dst/bin"

	echo "[PUSH] $src/lib/ -> $dst/lib"
    rsync -C --delete --exclude 'config.jar' --exclude 'libxerces*' -auv "$src/lib/" "$dst/lib" >/dev/null

}
