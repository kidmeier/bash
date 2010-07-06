function start-session() {

    if [ "$TERM" = "screen" ]
    then
        echo "Already running screen; kill or detach this session before starting a new one."
    else
        if [ "x$1" = "x" ]
        then
            screen -U
        else
            screen -U -S "$1"
        fi
    fi

}

function kill-session() {

   echo "TODO. Something with -X -r and C-a C-\ (quit)"

}

function resume() {

    if [ "x$1" = "x" ]
    then
        screen -U -D -R
    else
        screen -U -d -r "$1"
    fi

}

alias lss='screen -ls'
