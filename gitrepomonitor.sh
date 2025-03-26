#!/bin/bash

START=$(( $(date +%s%N) / 1000000 ))
SCRIPT=$(basename "$0")
SCRIPTNAME="${SCRIPT%.*}"
LOGFILE="/tmp/$SCRIPTNAME.log"
LOGDEBUG="/tmp/$SCRIPTNAME.dbg"
ICONFAIL="/usr/local/bin/failure.png"
DEBUG=0
VERSION="3.0.0"

RED="\033[91m"
GREEN="\033[92m"
YELLOW="\033[93m"
BLUE="\033[94m"
MAGENTA="\033[95m"
CYAN="\033[96m"
WHITE="\033[97m"
NC="\033[0m"

function logError
{
    echo -e "${RED}error:${NC} $1" >> $LOGFILE
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

function logIt
{
    echo -e "$1" >> $LOGFILE
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

function logDebug
{
    if [ $DEBUG -ne 0 ] ; then
        local RUNTIME
        RUNTIME=$(getRuntime)
        echo -e "[${RUNTIME}s] ${GREEN}debug:${NC} $1" >> $LOGDEBUG
    fi
}

function _help
{
cat << EOT
File to run a shell script program as a daemon.
Version: ${WHITE}$VERSION${NC}
Usage  : ${WHITE}$SCRIPT${NC} [option] <value>
Option:
 -h | --help                Show this help information and return.
 -d | --debug               Enable debug mode.
 -t | --interval <time>     Set a new interval in seconds to update the repository, default is 300s.
 -f | --file <filename>     Set repositories source list file, default is "git.list".
EOT
    return 0
}

function _update
{
    local STS
    local RES
    local MINS
    local DATE
    local REPO
    local WAIT
    local MINS
    local err
    local code

    REPO="$1"
    WAIT=$2
    err=0

    logDebug "Starting function _update( $REPO )"

    STS=$(git status)
    logDebug "$STS"
    if [[ $(echo "$STS" | grep -F "up to date"       ) ||    \
          $(echo "$STS" | grep -F "nothing to commit") ]] && \
     [[ ! $(echo "$STS" | grep -F "modified"         ) && \
        ! $(echo "$STS" | grep -F "untracked"        ) && \
        ! $(echo "$STS" | grep -F "deleted"          ) ]]
    then
        logDebug "Nothing to do"
    else
        logDebug "(git addd .)"
        RES=$(git addd . < /dev/null 2>&1 > /dev/null)
        code=$?
        logDebug "$RES"
        if [ $code -ne 0 ] ; then
            err=$((err+1))
            logDebug "git add . failed"
        else
            logDebug "Success run (git add .)"

            DATE=$(getDate)
            MINS=$((WAIT/60))
            logDebug "(git commit -m \"message $DATE, ...${WAIT}s|${MINS}m\")"
            RES=$(git commit -m "Auto update ran at $DATE, next in ${WAIT}s|${MINS}m" < /dev/null 2>&1 > /dev/null)
            code=$?
            logDebug "$RES"
            if [ $code -ne 0 ] ; then
                err=$((err+2))
                logDebug "git commit -m \"message\" failed."
            else
                logDebug "Success run command line (git commit -m \"message...\")"

                logDebug "(git pull)"
                RES=$(git pull origin < /dev/null 2>&1 > /dev/null)
                code=$?
                logDebug "$RES"
                if [ $code -ne 0 ] ; then
                    err=$((err+4))
                    logDebug "git pull origin failed"
                else
                    logDebug "Success run command line (git pull origin)"

                    logDebug "(git push)"
                    RES=$(git push origin < /dev/null 2>&1 > /dev/null)
                    code=$?
                    logDebug "$RES"
                    if [ $code -ne 0 ] ; then
                        err=$((err+8))
                        logError "git push origin failed"
                    else
                        logDebug "Success run command line (git push origin)"
                    fi
                fi
            fi
        fi
    fi

    if [ $err -ne 0 ] ; then
        notify-send -a $SCRIPT -u normal -t 15000 --icon=$ICONFAIL "Update ($REPO) error ($err)"
    fi

    return $err
}

function _exit
{
    # get error code parameters, empty set as zero.
    local CODE
    CODE=$( [ -n "$1" ] && echo $1 || echo 0 )
    logDebug "Exit code ($CODE)"
    # unset global variables
    unset -v START
    unset -v SCRIPTNAME
    unset -v SCRIPT
    unset -v ICONFAIL
    unset -v LOGFILE
    unset -v LOGDEBUG
    unset -v DEBUG
    unset -v VERSION
    unset -v RED
    unset -v GREEN
    unset -v YELLOW
    unset -v BLUE
    unset -v MAGENTA
    unset -v CYAN
    unset -v WHITE
    unset -v NC
    # unset functions
    unset -f main
    unset -f _update
    unset -f _help
    unset -f getRuntime
    unset -f getDate
    unset -f logIt
    unset -f logError
    unset -f logDebug
    unset -f logNewLine
    unset -f logClear
    unset -f _exit
    # exit error code
    exit $CODE
}

function main
{
    local STS
    local RES
    local DATE
    local LINE
    local RUNTIME
    local REPOSITORY

    local WORKDIR
    local USERDIR
    local FILE
    local WAIT
    local MINS

    WORKDIR="/var/home/$USER/dev"
    USERDIR="/var/home/$USER"
    FILE="git.list"
    WAIT=300
    MINS=$((WAIT/60))

    while [ -n "$1" ] ; do
        case "$1" in
        -h | --help)
            _help
            return $?
            ;;
        -d | --debug)
            # enable debug mode
            DEBUG=1
            # clear debug file
            echo > $LOGDEBUG
            # any error
            if [ $? -ne 0 ] ; then
                # disable debug mode
                DEBUG=0
                # log and error message
                logError "Could not start debug to log $LOGDEBUG file."
                # return an error code and exit
                return 1
            else
                logIt "DEBUG is ON."
            fi
            ;;
        -f | --file)
            shift
            local OLD=$FILE
            FILE=$( [ -n "$1" ] && echo "$1" || echo "git.list")
            logDebug "File repository list name changed from ($OLD) to ($FILE)."
            ;;
        -t | --interval)
            shift
            local OLD=$WAIT
            WAIT=$( [ -n "$1" ] && echo  $1  || echo 300)
            MINS=$((WAIT/60))
            logDebug "Interval time changed from (${OLD}s) to (${WAIT}s|${MINS}m)."
            ;;
        *)
            logDebug "Unknown parameter $1"
            logError "Unknown parameter $1"
            return 1
            ;;
        esac
        shift
    done

    logClear

    DATE=$(getDate)
    logDebug "Date $DATE"
    logDebug "WORK  Dir: $WORKDIR/"
    logDebug "USER  Dir: $USERDIR/"
    logDebug "FILE name: $FILE"
    logDebug "WAIT time: ${WAIT}s|${MINS}m"

    while [ true ]
    do
        logNewLine

        DATE=$(getDate)
        logIt "${WHITE}Date:${NC} $DATE"

        RUNTIME=$(getRuntime)
        logIt "${WHITE}runtime:${NC} ${RUNTIME}s"

        if cd $USERDIR ; then
            _update "$USER" $WAIT || logError "Update repository ($USER)"
        else
            logError "Change to $USERDIR/"
        fi

        if ! cd "$WORKDIR" ; then
            logError "Change to $WORKDIR/"
            reuturn 1
        fi

        while read -e LINE ; do
            # ignore empty lines
            [ -z "${LINE}" ] && continue
            # ignore commented lines
            [[ ${LINE:0:1} == "#" ]] && continue
            REPOSITORY="$LINE"

            if [ -d "$REPOSITORY" ] ; then
                cd "$REPOSITORY"

                if [ $? -eq 0 ] ; then
                    _update "$REPOSITORY" $WAIT || logError "Update repository ($REPOSITORY)"
                    cd ..
                else
                    logError "Change to directory $REPOSITORY"
                fi
            else
                logError "Repository $REPOSITORY from file $FILE does not exist."
            fi

        done < "$FILE"

        RUNTIME=$(getRuntime)
        logIt "${WHITE}runtime:${NC} ${RUNTIME}s"
        logDebug "Runtime ${RUNTIME}s"

        logIt "${WHITE}interval:${NC} Wait for ${WAIT}s|${MINS}m"
        logDebug "Waiting for ${WAIT}s|${MINS}m ..."

        sleep $WAIT
    done
}

main "$@"
_exit $?
