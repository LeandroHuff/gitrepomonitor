#!/bin/bash

START=$(( $(date +%s%N) / 1000000 ))
VERSION="3.0.0"
SCRIPTNAME=$(basename "$0")
DAEMONAME=${SCRIPTNAME%.*}
SYSTEMDDIR="/etc/systemd/system"
BINDIR="/usr/local/bin"
WORKDIR="/var/home/leandro/dev"
LOGFILE="/tmp/$DAEMONAME.log"
SECS=300
MINS=$((SECS/60))

function unsetVars
{
    unset -v START
    unset -v VERSION
    unset -v SCRIPTNAME
    unset -v DAEMONAME
    unset -v SYSTEMDDIR
    unset -v BINDIR
    unset -v WORKDIR
    unset -v LOGFILE
    unset -v SECS
    unset -v MINS

    unset -f msgError
    unset -f msgSuccess
    unset -f logError
    unset -f logSuccess
    unset -f getRuntime
    unset -f logNewLIne
    unset -f logClear
    unset -f logSaveDate
    unset -f logSaveIt
    unset -f logInterval
    unset -f _help
    unset -f _install
    unset -f parseParameters
    unset -f main
}

function msgError
{
    echo -e "\033[91merror:\033[0m $1"
}

function msgSuccess
{
    echo -e "\033[92msuccess:\033[0m $1"
}

function logError
{
    echo -e "\033[91merror:\033[0m $1" >> $LOGFILE
}

function logSuccess
{
    echo -e "\033[92msuccess:\033[0m $1" >> $LOGFILE
}

function getRuntime
{
    local NOW
    local RUNTIME
    NOW=$(( $(date +%s%N) / 1000000 ))
    RUNTIME=$((NOW-START))
    printf -v ELAPSED "%u.%03u" $((RUNTIME / 1000)) $((RUNTIME % 1000))
    echo -e "\033[97mruntime:\033[0m ${ELAPSED}s"
    unset -v ELAPSED
}

function logNewLine
{
    echo >> $LOGFILE
}

function logClear
{
    echo > $LOGFILE
}

function logDate
{
    local DATE
    DATE=$(date +%Y-%m-%dT%H:%M:%S)
    echo "\033[97mdate:\033[0m $DATE" >> $LOGFILE
    echo "$DATE"
}

function logIt
{
    echo "$1" >> $LOGFILE
}

function logInterval
{
    local secs=$1
    local mins=$2
    echo -e "\033[97minterval:\033[0m Wait for ${secs}s or ${mins}m" >> $LOGFILE
}

function _help
{
cat << EOT
File to run a shell script program as a daemon.
Version: $VERSION
Usage: $SCRIPTNAME [-h] | [-i] or $SCRIPTNAME [-t <time>]
Option:
 -h | --help                Show this help information.
 -i | --install             Prepare and install all files into each system folders.
 -t | --interval <time>     Set a new interval in seconds to update the repository, default is 300s.   

Obs.: Call script with -h or -i parameter will return from script to terminal without run as daemon.
EOT
    return 0
}

function _install
{
    local err=0

cat << EOT > /tmp/$DAEMONAME.service
[Unit]
Description=Git (Status/Commit/Push) Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $BINDIR/$SCRIPTNAME
WorkingDirectory=$WORKDIR
User=leandro
Group=leandro
Restart=on-failure
RestartSec=60
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOT
    if [ $? -eq 0 ] ; then
        msgSuccess "Create file /tmp/$DAEMONAME.service"
        sudo cp /tmp/$DAEMONAME.service $SYSTEMDDIR/
        if [ $? -ne 0 ] ; then
            err=$((err+1))
            msgError "Copy file /tmp/$DAEMONAME.service to $SYSTEMDDIR/"
        else
            msgSuccess "Copy file /tmp/$DAEMONAME.service to $SYSTEMDDIR/"
        fi
        rm -f /tmp/$DAEMONAME.service
    else
        err=$((err+2))
        msgError "Create file /tmp/$DAEMONAME.service"
    fi

    sudo cp ./$SCRIPTNAME $BINDIR/

    if [ $? -ne 0 ] ; then
        err=$((err+4))
        msgError "Copy $SCRIPTNAME file to $BINDIR/ directory."
    else
        msgSuccess "Copy $SCRIPTNAME file to $BINDIR/ directory."
    fi

    return $err
}

function _update
{
    local err=0
    local STS
    local RES

    STS=$(git status)
    if [[ $(echo "$STS" | grep -F "up to date"       ) ||    \
          $(echo "$STS" | grep -F "nothing to commit") ]] && \
       [[ ! $(echo "$STS" | grep -F "modified" ) && \
          ! $(echo "$STS" | grep -F "untracked") && \
          ! $(echo "$STS" | grep -F "deleted"  ) ]]
    then
        logSuccess "Nothing to do"
    else
        RES=$(git add .)
        if [ $? -ne 0 ] ; then
            err=$((err+1))
            logError "git add ."
            logIt "$RES"
        fi

        DATE=$(logDate)
        RES=$(git commit -m "Auto update ran at $DATE, next in ${SECS}s|${MINS}m")
        if [ $? -ne 0 ] ; then
            err=$((err+2))
            logError "git commit -m"
            logIt "$RES"
        fi

        RES=$(git push origin)
        if [ $? -ne 0 ] ; then
            err=$((err+4))
            logError "git push origin"
            logIt "$RES"
        fi
    fi

    return $err
}

function main
{
    while [ -n "$1" ] ; do
        case "$1" in
        -h | --help) _help ; return $? ;;
        -i | --install) _install ; return $? ;;
        -k) shift ; KEY="$1" ;;
        -t | --interval)
            shift
            SECS=$1
            MINS=$((SECS/60))
            ;;
        *) msgError "Unknown parameter $1" ; return 1 ;;
        esac
        shift
    done

    local STS
    local RES
    local DATE
    local LINE
    local RUNTIME
    local FILE="git.clone"

    logClear
    logDate

    cd "$WORKDIR" || { logError "Change to $WORKDIR/" ; return 1 ; }

    while [ true ]
    do
        logNewLine
        while read -e LINE ; do
            # junp empty lines
            [ -z "${LINE}" ] && continue
            # jump commented lines
            [[ ${LINE:0:1} == "#" ]] && continue
            RUNTIME=$(getRuntime)
            logIt "$RUNTIME"
            msgSuccess "Line: $LINE"
            if [ -d "$LINE" ] ; then
                msgSuccess "Dir $LINE exist"
                cd "$LINE"
                if [ $? -eq 0 ] ; then
                    _update
                    cd ..
                else
                    logError "Unkown repository $LINE"
                fi
            else
                msgSuccess "Dir $LINE not exist"
                msgSuccess "git clone -v --progress --recursive git@github.com:$KEY/$LINE.git"
                RES=$(git clone -v --progress --recursive git@github.com:$KEY/$LINE.git)
                if [ $? -ne 0 ] ; then
                    logError "Clone git repository $LINE.git"
                    logIt "$RES"
                fi
            fi
        done < "$FILE"
        RUNTIME=$(getRuntime)
        logIt "$RUNTIME"
        logInterval $SECS $MINS
        sleep $SECS
    done

    return 0
}

main "$@"
code=$?
unsetVars
exit $code
