#!/bin/bash

# global variables
START=$(( $(date +%s%N) / 1000000 ))
VERSION="3.0.0"
SCRIPTNAME=$(basename "$0")
DAEMONAME=${SCRIPTNAME%.*}
SYSTEMDDIR="/etc/systemd/system"
BINDIR="/usr/local/bin"
WORKDIR="/var/home/$USER/dev"
USERDIR="/var/home/$USER"
LOGFILE="/tmp/$DAEMONAME.log"
FILE="git.clone"
SECS=300

# unset all global vartiables and functions
function unsetVars
{
    unset -v START
    unset -v VERSION
    unset -v SCRIPTNAME
    unset -v DAEMONAME
    unset -v SYSTEMDDIR
    unset -v BINDIR
    unset -v WORKDIR
    unset -v USERDIR
    unset -v LOGFILE
    unset -v SECS
    unset -v FILE

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

# send an error message to terminal
function msgError
{
    echo -e "\033[91merror:\033[0m $1"
}

# send a success message to terminal
function msgSuccess
{
    echo -e "\033[92msuccess:\033[0m $1"
}

# send an error message to a log file
function logError
{
    echo -e "\033[91merror:\033[0m $1" >> $LOGFILE
}

# send a success message to a log file
function logSuccess
{
    echo -e "\033[92msuccess:\033[0m $1" >> $LOGFILE
}

# calculate the elapsed runtime and return a formatted message
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

# send a new line to log file
function logNewLine
{
    echo >> $LOGFILE
}

# clear all log file
function logClear
{
    echo > $LOGFILE
}

# send a formatted date to log file and return it to caller point
function logDate
{
    local DATE
    DATE=$(date +%Y-%m-%dT%H:%M:%S)
    echo -e "\033[97mdate:\033[0m $DATE" >> $LOGFILE
    echo -n "$DATE"
}

# send a message parameter to log file
function logIt
{
    echo -e "$1" >> $LOGFILE
}

# prepare an interval message and send it to log file
function logInterval
{
    local secs=$1
    local mins=$((secs/60))
    echo -e "\033[97minterval:\033[0m Wait for ${secs}s or ${mins}m" >> $LOGFILE
}

# print help message and information to terminal
function _help
{
cat << EOT
File to run a shell script program as a daemon.
Version: $VERSION
Usage: $SCRIPTNAME [-h] | [-i] or $SCRIPTNAME < -k|--key <GitUserName> > [ -t <time> ]
Option:
 -h | --help                Show this help information.
 -i | --install             Prepare and install all files into each system folders.
 -t | --interval <time>     Set a new interval in seconds to update the repository, default is 300s.
 -k | --key <GitUserName>   Set github user for pull and push commands.

Obs.: Call script with -h or -i parameter will return from script to terminal without run as daemon.
EOT
    return 0
}

# prepare the program as a daemon and install it as daemon on systemd
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
    local MINS
    local REPO="$1"

    STS=$(git status)
    if [[ $(echo "$STS" | grep -F "up to date"       ) ||    \
          $(echo "$STS" | grep -F "nothing to commit") ]] && \
       [[ ! $(echo "$STS" | grep -F "modified" ) && \
          ! $(echo "$STS" | grep -F "untracked") && \
          ! $(echo "$STS" | grep -F "deleted"  ) ]]
    then
        logSuccess "Nothing to do for repository $REPO"
    else
        RES=$(git add .)
        if [ $? -ne 0 ] ; then
            err=$((err+1))
            logError "git add ."
            logIt "$RES"
        fi

        DATE=$(logDate)
        MINS=$((SECS/60))
        RES=$(git commit -m "Auto update ran at $DATE, next in ${SECS}s|${MINS}m")
        if [ $? -ne 0 ] ; then
            err=$((err+2))
            logError "git commit -m"
            logIt "$RES"
        fi

        RES=$(git pull origin)
        if [ $? -ne 0 ] ; then
            err=$((err+2))
            logError "git pull origin"
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
        -k | --key) shift ; KEY="$1" ;;
        -f | --file) shift ; FILE="$1" ;;
        -t | --interval) shift ; SECS=$1 ;;
        *) msgError "Unknown parameter $1" ; return 1 ;;
        esac
        shift
    done

    local STS
    local RES
    local DATE
    local LINE
    local RUNTIME
    local REPOSITORY

    logClear
    DATE=$(logDate)

    while [ true ]
    do
        logNewLine
        RUNTIME=$(getRuntime)
        logIt "$RUNTIME"
        cd $USERDIR || logError "Change to $USERDIR/"
        _update "$USER"
        cd "$WORKDIR" || logError "Change to $WORKDIR/"
        while read -e LINE ; do
            # junp empty lines
            [ -z "${LINE}" ] && continue
            # jump commented lines
            [[ ${LINE:0:1} == "#" ]] && continue
            # directory exist ?
            REPOSITORY="$LINE"
            if [ -d "$REPOSITORY" ] ; then
                # change to directory
                cd "$REPOSITORY"
                if [ $? -eq 0 ] ; then
                    # update git repository
                    _update "$REPOSITORY"
                    # move back for next one
                    cd ..
                else
                    logError "Unkown repository $REPOSITORY"
                fi
            else
                logIt "git clone -v --progress --recursive git@github.com:$KEY/$REPOSITORY.git"
                RES=$(git clone -v --progress --recursive git@github.com:$KEY/$REPOSITORY.git)
                if [ $? -ne 0 ] ; then
                    logError "Clone git repository $REPOSITORY.git"
                    logIt "$RES"
                fi
            fi
        done < "$FILE"
        RUNTIME=$(getRuntime)
        logIt "$RUNTIME"
        logInterval $SECS
        sleep $SECS
    done
    # should never reach from this point.
    return 0
}

main "$@"
code=$?
unsetVars
exit $code
