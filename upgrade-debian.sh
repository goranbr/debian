#!/bin/bash

#-------------------------------------------------------------------------------------------------
# Prompt for yes or no
# Positional parameters: 
#   1) question - if not specified the phrase "Continue?" is used.
#-------------------------------------------------------------------------------------------------

function ask {

    question=${1:-"Continue?"}
    while true; do
        echo
        read -r -p "${question} (y/n): " yn
        case $yn in
            [Yy]* ) echo; return 0;;
            [Nn]* ) echo; return 1;;
            * ) echo "Please, answer y or n!";;
        esac
    done
}

#-------------------------------------------------------------------------------------------------
# Print stripe of 100 dashes
#-------------------------------------------------------------------------------------------------

function stripe {
    for x in $(seq 1 100); do echo -e "-\c"; done; echo
}

#-------------------------------------------------------------------------------------------------
# Print a headline for one step of the script procedure
#-------------------------------------------------------------------------------------------------

function headline {
    echo; stripe; echo "# $1"; stripe; echo
}

#-------------------------------------------------------------------------------------------------
# Before distribution upgrade: Check for running database services
#-------------------------------------------------------------------------------------------------

headline "Check for running databases"
databases="mariadb postgresql mongod mysql"

for i in $databases
do
    if $(systemctl status $i > /dev/null 2>&1)
    then
        echo "The database $i is running on this machine. Take a backup and shut it down!"
        exit 1
    else
        echo "- $i is not running - ok"
    fi
done

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Operating System Backup
#-------------------------------------------------------------------------------------------------

headline "System backup"
if ask "Have you taken a system backup?"; then
    echo "System backup taken - Ok."
else
    echo "Upgrade aborted. Take a backup first!"
    exit 1
fi

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Announce downtime in OP5
#-------------------------------------------------------------------------------------------------

headline "OP5 Monitoring"

if ask "Have you scheduled server downtime in OP5?"; then
    echo "Downtime scheduled - Ok"
else
    echo "Upgrade aborted. Server downtime must be scheduled first."
    exit 1
fi    

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Sufficient free storage left 
#-------------------------------------------------------------------------------------------------

headline "Free storage"

echo "Ensuring there is enough free storage left on this machine...:"
#apt-get -o APT::Get::Trivial-Only=true dist-upgrade | awk '/After this operation/'
checkDisk=$(df     --out=target,avail / | awk ' NR==2 {print $2}')
checkDiskH=$(df -h --out=target,avail / | awk ' NR==2 {print $2}')

if [ "$checkDisk" -gt "2000000" ];then
    echo "Yes, $checkDiskHi Mb"
else
    echo "Upgrade aborted. Less than 2GB free storage left."
    exit 1
fi
ask

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Check which Pupper server uses
#-------------------------------------------------------------------------------------------------

# TODO: Server names should be configurable as variables at the top of the script

headline "Puppet server membership"

puppet_right="prod-int-pe1.skolverket.se"
puppet_used=$(grep server /etc/puppetlabs/puppet/puppet.conf | awk '{print $3}')

echo "Checking which Puppet server this machine is a member of..."

# TODO: Server name should be parameterized
if [ "$puppet_used" == "$puppet_right" ]; then
    echo "You are on the right puppet server ($puppet_right)!"
else
    echo "Upgrade aborted. The server is on puppet server ${puppet_used}."
    exit 1
fi
ask

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Check if packets are put on hold
#-------------------------------------------------------------------------------------------------

headline "Held packages"

check "Checking if packets are put on hold:"
dpkg --get-selections "*" | tee ~/curr-pkgs.txt
if ask "Continue?"; then
    echo "Got permission to continue - Ok"
else
    echo "Upgrade aborted."
fi  

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Run a puppet Dryrun?
#-------------------------------------------------------------------------------------------------

headline "Puppet Dry-Run"

if ask "Run: Puppet Agent Dry-Run?"; then
    puppet agent -t --noop
fi

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Run a full puppet run?
#-------------------------------------------------------------------------------------------------

headline "Puppet Run"

if ask "Run: Puppet Agent?"; then
    puppet agent -t
fi

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Check running services that should not be running
#-------------------------------------------------------------------------------------------------

# TODO: The list of services should perhaps be configurable in a config file?

headline "Shutting down services"

# Define list of services that should not run during distribution upgrade
services="auth-entrust jenkins puppet pxp-agent mcollective mariadb postgresql mongod mysql "
services+="solr ci session-c1.scope kibana apache apache2 nginx unicorn prometheus http tomcat "
services+="susanavet2 jboss gitlab-runsvdir.service slapd exim4"

echo "Shutting down services that should not be running during upgrade..."
for srv in $services
do
    if $(systemctl status $srv > /dev/null 2>&1 )
    then
        if ask "Shut down ${srv}?"; then
            echo "Aborting upgrade. All major services has to be shut down before upgrade."
            exit 1
        else
            systemctl stop $srv
        fi
    fi
done

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Change the APT repositories
#-------------------------------------------------------------------------------------------------

# TODO: Distro versions from/to should be parameterized

headline "Changing the repositories"

src_ver="jessie"
dst_ver="stretch"

ask "Change the repositories from '$src_ver' to '$trg_ver' for distribution upgrade?"
sed -i "s/$src_ver/$dst_ver/g" /etc/apt/sources.list.d/*
echo "Repositories set for distribution upgrade to version '$dst_ver'."

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Update APT package index
#-------------------------------------------------------------------------------------------------

headline "Update APT package index"

if ask "Run: apt-get update?"; then
    apt-get update
else
    echo "APT system will not be updated. Assuming this has already been done."
fi    

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Upgrade APT packages
#-------------------------------------------------------------------------------------------------

headline "Upgrade APT packages (current distribution)"

if ask "Run: apt-get upgrade?"; then
    apt-get upgrade
else
    echo "APT packages will not be updated. Assuming this has already been done."
fi    

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Run the full dist upgrade 
#-------------------------------------------------------------------------------------------------

headline "Perform distribution upgrade"

if ask "Run: apt-get dist-upgrade?"; then
    apt-get dist-upgrade
else
    echo "Upgrade aborted. No distribution upgrade will be performed."
fi    

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Autoremove unneccessary packages
#-------------------------------------------------------------------------------------------------

headline "Autoremoval of redundant packages" 

if ask "Run: apt-get autoremove?"; then
    apt-get autoremove
else
    echo "No autoremoval will be performed."
fi    

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Run a full puppet run
#-------------------------------------------------------------------------------------------------

headline "Full Puppet run"

if ask "Run a full puppet run?"; then
    puppet agent -t
else
    echo "No puppet run will be performed."
fi

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Check status of packages that have not succeeded
#-------------------------------------------------------------------------------------------------

headline "Check status of packages that have not succeeded"

dpkg --audit
ask

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Check for existence of a linux-image metapackage
#-------------------------------------------------------------------------------------------------

headline "Check for linux-image metapackage"

echo -e "Check for existence of a linux-image metapackage:\n"
dpkg -l "linux-image*" | grep ^ii | grep -i meta
ask

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Check for config files left after autoremove operation
#-------------------------------------------------------------------------------------------------

headline "Packages that retain config files after autoremove command"

echo -e "Packages that retain config files after autoremove command:\n"
dpkg -l | awk '/^rc/ { print $2 }'
ask

echo
if ask "Remove these config files?"; then
    apt-get purge $(dpkg -l | awk '/^rc/ { print $2 }')
fi

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Check that avahi service is disabled
#-------------------------------------------------------------------------------------------------

# TODO: this should be defined as a list of services that we can loop through
headline "Check for unwanted services"

echo -e "Check that avahi service is disabled:\n"
if systemctl list-unit-files | grep avahi; then
    systectl disable avahi && echo "Service avahi disabled" 
else    
    echo "Service avahi is disabled."
fi

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Reboot the machine
#-------------------------------------------------------------------------------------------------

headline "System reboot"

echo "IMPORTANT!! After restarting the machine check logs to ensure all services are up and running."
if ask "Reboot the machine?"; then
    reboot
else
    echo "In order for the many of the services to run on upgraded software you have to reboot your machine."   
fi

