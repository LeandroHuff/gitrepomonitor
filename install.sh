#!/bin/bash

# global variables
START=$(( $(date +%s%N) / 1000000 ))
VERSION="3.0.0"
SCRIPTNAME=$(basename "$0")
DAEMONAME="gitrepomonitor.sh"
SYSTEMDDIR="/etc/systemd/system"
BINDIR="/usr/local/bin"
WORKDIR="/var/home/$USER/dev"
USERDIR="/var/home/$USER"

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

    unset -f msgError
    unset -f msgSuccess
    unset -f getRuntime
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

# print help message and information to terminal
function _help
{
cat << EOT
Shell script program to install $DAEMONAME as a daemon service.
Version: $VERSION
Usage: $SCRIPTNAME [-h] | [-i] or $SCRIPTNAME < -k|--key <GitUserName> > [ -t <time> ]
Option:
 -h | --help            Show this help information.
 -b | --bindir          Set binary directory destine.
 -s | --sysdir          Set service directory destine.
 -n | --appname         Set daemon application name+ext
 -w | --worksir         Set work directory.
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
ExecStart=/bin/bash $BINDIR/$DAEMONAME
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

# main application function, it have an infinite looping to
# check local git repositories and proceed to update it if needed.
function main
{
    # start parse all command line parameters
    while [ -n "$1" ] ; do
        case "$1" in
        -h | --help) _help ; return $? ;;
        -b | --bindir) shift ; $BINDIR="$1" ;;
        -s | --sysdir) shift ; $SYSTEMDDIR="$1" ;;
        -n | --appname) shift ; $SCRIPTNAME="$1" ; DAEMONAME=${SCRIPTNAME%.*} ;;
        -w | --workdir) shift ; $WORKDIR="$1" ;;
        *) logError "Unknown parameter $1" ; return 1 ;;
        esac
        shift
    done
    _install
    return $?
}

# shell script entry point, call main() function and
# pass all command line parameter "$@" to it.
main "$@"
# store returned code
code=$?
# unset all glocal variables and functions
unsetVars
# exit with code
exit $code
