#!/bin/bash

START=$(( $(date +%s%N) / 1000000 ))
SCRIPTNAME=$(basename "$0")
LOGFILE="/tmp/${SCRIPTNAME%.*}.log"
VERSION="3.0.0"

function logError
{
    echo -e "\033[91merror:\033[0m $1" >> $LOGFILE
}

function logSuccess
{
    echo -e "\033[92msuccess:\033[0m $1" >> $LOGFILE
}

function logNewLine
{
    echo >> $LOGFILE
}

function logClear
{
    echo > $LOGFILE
}

function getDate
{
    local DATE
    DATE=$(date +%Y-%m-%dT%H:%M:%S)
    echo -n "$DATE"
}

function logDate
{
    local DATE
    DATE=$(getDate)
    echo -e "\033[97mdate:\033[0m $DATE" >> $LOGFILE
}

function logIt
{
    echo -e "$1" >> $LOGFILE
}

function logInterval
{
    local secs=$1
    local mins=$((secs/60))
    echo -e "\033[97minterval:\033[0m Wait for ${secs}s or ${mins}m" >> $LOGFILE
}

function getRuntime
{
    local NOW
    local RUNTIME
    NOW=$(( $(date +%s%N) / 1000000 ))
    RUNTIME=$((NOW-START))
    printf -v ELAPSED "%u.%03u" $((RUNTIME / 1000)) $((RUNTIME % 1000))
    echo -n "$ELAPSED"
    unset -v ELAPSED
}

function logRuntime
{
    echo -e "\033[97mruntime:\033[0m $1s" >> $LOGFILE
}

function _help
{
cat << EOT
File to run a shell script program as a daemon.
Version: $VERSION
Usage: $SCRIPTNAME [-h] or $SCRIPTNAME < -k|--key <GitUserName> > [ -t <time> ]
Option:
 -h | --help                Show this help information.
 -t | --interval <time>     Set a new interval in seconds to update the repository, default is 300s.
 -f | --file <filename>     Set repositories source list file.
Obs.: Call script with -h parameter will return from script to terminal without run as daemon.
EOT
    return 0
}

function _update
{
    local err=0
    local STS
    local RES
    local MINS
    local DATE
    local REPO="$1"

    STS=$(git status)
    if [[ $(echo "$STS" | grep -F "up to date"       ) ||    \
          $(echo "$STS" | grep -F "nothing to commit") ]] && \
     [[ ! $(echo "$STS" | grep -F "modified"         ) && \
        ! $(echo "$STS" | grep -F "untracked"        ) && \
        ! $(echo "$STS" | grep -F "deleted"          ) ]]
    then
        :
    else
        RES=$(git add .)
        if [ $? -ne 0 ] ; then
            err=$((err+1))
            logError "git add . failed for repository $REPO"
            logIt "$RES"
        fi

        DATE=$(getDate)
        MINS=$((SECS/60))
        RES=$(git commit -m "Auto update ran at $DATE, next in ${SECS}s|${MINS}m")
        if [ $? -ne 0 ] ; then
            err=$((err+2))
            logError "git commit -m \"message\" failed for repository $REPO"
            logIt "$RES"
        fi

        RES=$(git pull origin)
        if [ $? -ne 0 ] ; then
            err=$((err+4))
            logError "git pull origin failed for repository $REPO"
            logIt "$RES"
        fi

        RES=$(git push origin)
        if [ $? -ne 0 ] ; then
            err=$((err+8))
            logError "git push origin failed for repository $REPO"
            logIt "$RES"
        fi
    fi

    return $err
}

function main
{
    WORKDIR="/var/home/$USER/dev"
    USERDIR="/var/home/$USER"
    FILE="git.clone"
    SECS=300

    while [ -n "$1" ] ; do
        case "$1" in
        -h | --help)             _help ; return $? ;;
        -f | --file)     shift ; FILE="$1" ;;
        -t | --interval) shift ; SECS=$( [ -n "$1" ] && echo $1 || echo 300) ;;
        *)                       logError "Unknown parameter $1" ; return 1 ;;
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

    while [ true ]
    do
        logNewLine
        logDate
        RUNTIME=$(getRuntime)
        logIt "$RUNTIME"
        cd $USERDIR || logError "Change to $USERDIR/"
        _update "$USER"
        cd "$WORKDIR" || logError "Change to $WORKDIR/"
        while read -e LINE ; do
            # ignore empty lines
            [ -z "${LINE}" ] && continue
            # ignore commented lines
            [[ ${LINE:0:1} == "#" ]] && continue
            REPOSITORY="$LINE"
            if [ -d "$REPOSITORY" ] ; then
                cd "$REPOSITORY"
                if [ $? -eq 0 ] ; then
                    _update "$REPOSITORY"
                    cd ..
                else
                    logError "Change to directory $REPOSITORY"
                fi
            else
                logError "Repository $REPOSITORY from file $FILE does not exist."
            fi
        done < "$FILE"
        RUNTIME=$(getRuntime)
        logRuntime "$RUNTIME"
        logInterval $SECS
        sleep $SECS
    done
}

main "$@"
