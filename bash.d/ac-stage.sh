function push-stage() {

    if [ -n "$1" ]
    then
        src=$1
        shift
    else
        src=$PWD
    fi

    dst=$HOME/devl/tptp/stage

    rsync -C --delete --exclude '*.sh' --exclude 'RAServer' --exclude 'tptpcore\
.jar' -auv "$src/bin/" "$dst/bin"
    rsync -C --delete --exclude 'config.jar' --exclude 'libxerces*' -auv "$src/\
lib/" "$dst/lib"

}
