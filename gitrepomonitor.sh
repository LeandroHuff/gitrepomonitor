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
# daemoname.service will be copyied to /etc/systemd/system/ directory.
# scriptname.sh will be copyied to /usr/local/bin/ directory.
# enable, start, and get status of daemon using systemctl system application.
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

# check git repository status and proceed to update by
# add, commit and push it to online github repository.
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
            logError "git commit -m \"message\""
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

# main application function, it have an infinite looping to
# check local git repositories and proceed to update it if needed.
function main
{
    # start parse all command line parameters
    while [ -n "$1" ] ; do
        case "$1" in
        # help parameter (optional)
        -h | --help) _help ; return $? ;;
        # install parameter (optional)
        -i | --install) _install ; return $? ;;
        # git user parameter (obligatory)
        -k | --key) shift ; KEY="$1" ;;
        # git repository file list (optional, default is git.clone)
        -f | --file) shift ; FILE="$1" ;;
        # interval parameter (optional, default is 300s)
        -t | --interval) shift ; SECS=$( [ -n "$1" ] echo $1 || echo 300) ;;
        # for empty or invalid parameter, print an error message on log.
        *) logError "Unknown parameter $1" ; return 1 ;;
        esac
        # next parameter from command line.
        shift
    done

    # local variables
    local STS
    local RES
    local DATE
    local LINE
    local RUNTIME
    local REPOSITORY

    # clear log file
    logClear

    # start an infinite looping
    while [ true ]
    do
        # add a new line on log file
        logNewLine
        # save date on log file
        DATE=$(logDate)
        # save the runtime value on log file
        RUNTIME=$(getRuntime)
        logIt "$RUNTIME"
        # change to user directory or log an error.
        cd $USERDIR || logError "Change to $USERDIR/"
        # update git hub repository from user directory.
        _update "$USER"
        # change to work directory .../dev/ and update git hub repository.
        cd "$WORKDIR" || logError "Change to $WORKDIR/"
        # open $FILE and read line by line from it using each one as a repository name.
        while read -e LINE ; do
            # junp empty lines
            [ -z "${LINE}" ] && continue
            # jump commented lines
            [[ ${LINE:0:1} == "#" ]] && continue
            # repository/directory exist on file system?
            REPOSITORY="$LINE"
            if [ -d "$REPOSITORY" ] ; then
                # change to directory
                cd "$REPOSITORY"
                # no errors then...
                if [ $? -eq 0 ] ; then
                    # update git repository
                    _update "$REPOSITORY"
                    # move back for next one
                    cd ..
                else # for any error, send a message to log file
                    logError "Unkown repository $REPOSITORY"
                fi
            else # does not exist yet.
                # save the command line to log file
                logIt "git clone -v --progress --recursive git@github.com:$KEY/$REPOSITORY.git"
                # run the command line
                RES=$(git clone -v --progress --recursive git@github.com:$KEY/$REPOSITORY.git)
                # any error
                if [ $? -ne 0 ] ; then
                    # save a message on log file
                    logError "Clone git repository $REPOSITORY.git"
                    # save command line result into log file
                    logIt "$RES"
                fi
            fi
        # read next line until the end of file $FILE
        done < "$FILE"
        # save the runtime value into log file.
        RUNTIME=$(getRuntime)
        logIt "$RUNTIME"
        # save interval into log file
        logInterval $SECS
        # wait some seconds until the next looping
        sleep $SECS
    done
    # should never reach this point, because
    # the shell script is a daemon and has an infinite looping in it.
    return 0
}

# shell script entry point, call main() function and
# pass all command line parameter "$@" to it.
# this function should never come back, because it has an infinite loop inside.
# its the daemon architecture, run on memory and never stop until kill the application.
main "$@"

# store returned code
code=$?
# unset all glocal variables and functions
unsetVars
# exit with code
exit $code
