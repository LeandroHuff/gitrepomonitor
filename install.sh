#!/bin/bash

# global variables
START=$(( $(date +%s%N) / 1000000 ))
VERSION="2.0.0"
SCRIPTNAME=$(basename "$0")
DAEMONAPP="gitrepomonitor.sh"
DAEMONAME=${DAEMONAPP%.*}
SYSDIR="/etc/systemd/system"
BINDIR="/usr/local/bin"
WORKDIR="/var/home/$USER/dev"
USERDIR="/var/home/$USER"
RELOAD=0

# unset all global vartiables and functions
function unsetVars
{
    unset -v START
    unset -v VERSION
    unset -v SCRIPTNAME
    unset -v DAEMONAPP
    unset -v DAEMONAME
    unset -v SYSDIR
    unset -v BINDIR
    unset -v WORKDIR
    unset -v USERDIR
    unset -v RELOAD

    unset -f msgError
    unset -f msgSuccess
    unset -f getRuntime
    unset -f _help
    unset -f _install
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

function msgWarning
{
    echo -e "\033[96mwarning:\033[0m $1"
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
Shell script program to install $DAEMONAPP as a daemon service.
Version: $VERSION
Usage  : $SCRIPTNAME [-h] or $SCRIPTNAME [option] <value>
 -h | --help                    Show this help information.
Options:
 -b | --bindir  <directory>     Set binary directory destine.
 -s | --sysdir  <directory>     Set service directory destine.
 -n | --appname <name>          Set daemon application name+ext
 -w | --workdir <directory>     Set work directory.
 -r | --reload                  Enable reload daemon service at the end.
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
    local SERVICEFILE="$DAEMONAME.service"
    local SCRIPTFILE="$DAEMONAPP"

cat << EOT > /tmp/$DAEMONAME.service
[Unit]
Description=Git (Status/Commit/Push) Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $BINDIR/$SCRIPTFILE -d
WorkingDirectory=$USERDIR
User=$USER
Group=$USER
Restart=on-failure
RestartSec=60
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOT

    if [ $? -eq 0 ] ; then
        msgSuccess "Create file /tmp/$SERVICEFILE"
        sudo cp /tmp/$SERVICEFILE $SYSDIR/
        if [ $? -ne 0 ] ; then
            err=$((err+1))
            msgError "Copy file /tmp/$SERVICEFILE to $SYSDIR/"
        else
            msgSuccess "Copy file /tmp/$SERVICEFILE to $SYSDIR/"
        fi
        rm -f /tmp/$SERVICEFILE
    else
        err=$((err+2))
        msgError "Create file /tmp/$SERVICEFILE"
    fi

    sudo cp ./$SCRIPTFILE $BINDIR/

    if [ $? -ne 0 ] ; then
        err=$((err+4))
        msgError "Copy $SCRIPTFILE file to $BINDIR/ directory."
    else
        msgSuccess "Copy $SCRIPTFILE file to $BINDIR/ directory."
    fi

    return $err
}

# main application function, it have an infinite looping to
# check local git repositories and proceed to update it if needed.
function main
{
    local err=0

    while [ -n "$1" ] ; do
        case "$1" in
        -h | --help)    _help
                        return $?
                        ;;

        -b | --bindir)  shift
                        BINDIR="$1"
                        ;;

        -s | --sysdir)  shift
                        SYSDIR="$1"
                        ;;

        -n | --appname) shift
                        SCRIPTNAME="$1"
                        DAEMONAME=${SCRIPTNAME%.*}
                        ;;

        -w | --workdir) shift
                        WORKDIR="$1"
                        ;;

        -r | --reload) RELOAD=1
                       ;;

        *)              msgError "Unknown parameter $1"
                        return 1
                        ;;
        esac
        shift
    done

    _install

    if [ $? -eq 0 ] ; then
        msgSuccess "Install $DAEMONAME daemon service."
        if [ $RELOAD -ne 0 ] ; then
            sudo systemctl stop "$DAEMONAME.service" || err=$((err+2))
            sleep 0.5
            sudo systemctl disable "$DAEMONAME.service" || err=$((err+4))
            sleep 0.5
            sudo systemctl daemon-reload || err=$((err+8))
            sleep 0.5
            sudo systemctl enable "$DAEMONAME.service" || err=$((err+16))
            sleep 0.5
            sudo systemctl start "$DAEMONAME.service" || err=$((err+32))
            if [ $err -eq 0 ] ; then
                msgSuccess "Run all systemctl command line."
            else
                msgError "systemctl command returned one or more error codes."
            fi
        else
            msgWarning "Flag auto-reload was not set from command line."
        fi
    else
        msgError "Install daemon $DAEMONAPP and/or $DAEMONAME.service failure."
        err=$((err+64))
    fi
    return $err
}

# shell script entry point, call main() function and
# pass all command line parameter "$@" to it.
main "$@"
code=$?
unsetVars
exit $code
