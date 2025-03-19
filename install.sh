#!/bin/bash

DEBUG=0

function error
{
    printf "\033[91merror  :\033[0m %s\n" "$1"
}

function debug
{
    [ $DEBUG -ne 0 ] && printf "\033[92mdebug  :\033[0m %s\n" "$1"
}

function success
{
    printf "\033[97msuccess:\033[0m %s\n" "$1"
}


function unsetVars
{
    unset -v DEBUG
    unset -f error
    unset -f debug
    unset -f unsetVars
    unset -f _exit
    unset -f _help
    unset -f main
}

function _exit
{
    local code=$([ -n "$1" ] && echo $1 || echo 0])
    unsetVars
    exit $code
}

function _help
{
    local SCRIPT=$(basename "$0")
    cat << EOT
Script program to automate install a service test daemon."

Usage: $SCRIPT [-h] | [-d] [options]

 -h     Show help information.
 -d     Enable debug messages.

[Options]

 -n  <name>     Set daemon name.
 -sn <name>     Set service ename as name.service
 -sd <dir>      Set service directory.
 -td <dir>      Set target directory.

EOT
}

function main
{
    local force=0
    local DAEMON="gitrepomonitor.sh"
    local DAEMONAME=${DAEMON%.*}
    local SERVICENAME="${DAEMONAME}.service"
    local SERVICEDIR="/etc/systemd/system"
    local TARGETDIR="/usr/local/bin"

    while [ -n "$1" ] ; do
        case "$1" in
        -h)
            _help
            return 0
            ;;
        -d)
            DEBUG=1
            debug "[DEBUG] flag was set to ON."
            ;;
        -f)
            force=1
            debug "[FORCE] flag was set to ON."
            ;;
        -n)
            shift
            DAEMONAME="$1"
            debug "DAEMONAME was set to $DAEMONAME"
            ;;
        -sn)
            shift
            SERVICENAME="$1.service"
            debug "SERVICENAME was set to $SERVICENAME"
            ;;
        -sd)
            shift
            SERVICEDIR="$1"
            debug "SERVICENAME was set to $SERVICEDIR"
            ;;
        -td)
            shift
            TARGETDIR="$1"
            debug "TARGETDIR was set to $TARGETDIR"
            ;;
        *)
            error "Unknown parameter [$1]"
            ;;
        esac
        shift
    done

    if ! [ -d $SERVICEDIR ] ; then
        error "$SERVICEDIR does not exist."
        return 1
    else
        debug "$SERVICEDIR directory already exist."
    fi

    if ! [ -f $SERVICEDIR/$SERVICENAME ] || [ $force -ne 0 ] ; then
        debug "cp $SERVICENAME $SERVICEDIR/"
        sudo cp $SERVICENAME $SERVICEDIR/
        if [ $? -ne 0 ] ; then
            error "Copy daemon $SERVICENAME to $SERVICEDIR/"
            return 1
        fi
    else
        debug "$SERVICEDIR/$SERVICENAME file already exist."
    fi

    if ! [ -f $TARGETDIR/$DAEMON ] || [ $force -ne 0 ]  ; then
        debug "sudo cp $DAEMON $TARGETDIR/"
        sudo cp $DAEMON $TARGETDIR/
        if [ $? -ne 0 ] ; then
            error  "Copy daemon $DAEMON to $TARGETDIR/"
            return 1
        fi
    else
        debug "$TARGETDIR/$DAEMON file already exist."
    fi

    success "copy all files for $DAEMONAME"

    sleep 0.5

    debug "sudo systemctl stop $SERVICENAME"
    sudo systemctl stop $SERVICENAME

    sleep 0.5

    debug "sudo systemctl disable $SERVICENAME"
    sudo systemctl disable $SERVICENAME

    sleep 0.5

    debug "sudo systemctl daemon-reload"
    sudo systemctl daemon-reload

    sleep 0.5

    debug "sudo systemctl start $SERVICENAME"
    sudo systemctl start $SERVICENAME

    sleep 0.5

    debug "sudo systemctl enable $SERVICENAME"
    sudo systemctl enable $SERVICENAME

    sleep 0.5

    debug "sudo systemctl status $SERVICENAME"
    sudo systemctl status $SERVICENAME

    return 0
}

main "$@"
_exit $?
