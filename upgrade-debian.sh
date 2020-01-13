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
            [Nn]* ) exit;;
            * ) echo "Please, answer y or n!";;
        esac
    done
}

#-------------------------------------------------------------------------------------------------
# Print a headline for one step of the script procedure
#-------------------------------------------------------------------------------------------------

function headline {
    echo
    echo "----------------------------------------------------------------------------------------"
    echo "# $1"
    echo "----------------------------------------------------------------------------------------"
    echo
}

#-------------------------------------------------------------------------------------------------
# Before distribution upgrade: Check for running database services
#-------------------------------------------------------------------------------------------------

headline "Checking for running databases..."
databases="mariadb postgresql mongod mysql"
for i in $databases
do
    if $(systemctl status $i > /dev/null 2>&1)
    then
        echo "ERROR: There are one or more databases running on this machine. Take a BACKUP!"
	echo "$i"
        exit 1
    fi
done

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Operating System Backup
#-------------------------------------------------------------------------------------------------

headline "System backup"
ask "Have you taken a system backup?"

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Announce downtime in OP5
#-------------------------------------------------------------------------------------------------

headline "OP5 Monitoring"
ask "Have you scheduled downtime in OP5?"

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Sufficient free storage left 
#-------------------------------------------------------------------------------------------------

headline "Ensuring there is enough free storage left on this machine:"
#apt-get -o APT::Get::Trivial-Only=true dist-upgrade | awk '/After this operation/'
checkDisk=$(df --out=target,avail /     | awk ' NR==2 {print $2}')
checkDiskH=$(df -h --out=target,avail / | awk ' NR==2 {print $2}')
if [ "$checkDisk" -gt "2000000" ];then
    echo "Yes, $checkDiskH"
else
    echo "No, less than 2GB free storage left."
    exit 1
fi
ask

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Check which Pupper server it is a member of
#-------------------------------------------------------------------------------------------------

# TODO: This should be configurable as an environment variable

headline "Check which Puppet server this machine is a member of:"
newPuppet=$(grep server /etc/puppetlabs/puppet/puppet.conf | awk '{print $3}')
oldPuppet="prod-int-puppet1.skolverket.se"

# TODO: Server name should be parameterized
if [ $newPuppet == "prod-int-pe1.skolverket.se" ]
then
    echo "You are on the right puppet server ($newPuppet)!"
else
    echo "You are on the old puppet server ($oldPuppet). Aborting..."
    exit 1
fi
ask

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Check if packets are put on hold
#-------------------------------------------------------------------------------------------------

headline "Check if packets are put on hold:"
dpkg --get-selections "*" | tee ~/curr-pkgs.txt
ask

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Run a puppet Dryrun?
#-------------------------------------------------------------------------------------------------

headline "Puppet Dry-run"
echo
if ask "Run: puppet dry-run?"
    puppet agent -t --noop
fi
echo

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Run a full puppet run?
#-------------------------------------------------------------------------------------------------

headline "Full Puppet run"
if ask "Run: a full puppet run?"
    puppet agent -t
fi
echo

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Check running services that should not be running
#-------------------------------------------------------------------------------------------------

# TODO: This step does not allow for services not existing/running on a particular server

headline "Shut down services that should not be running during upgrade:"
services="auth-entrust jenkins puppet pxp-agent mcollective mariadb postgresql mongod mysql solr ci session-c1.scope kibana apache apache2 nginx unicorn prometheus http tomcat susanavet2 jboss gitlab-runsvdir.service slapd exim4"

for i in $services
do
    if $( systemctl status $i > /dev/null 2>&1 )
    then
        read -r -p "Shut down $i? "
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborting script. All services has to be shut down before upgrade."
            exit 1
        else
            systemctl stop $i
        fi
    fi
done

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Change the APT repositories
#-------------------------------------------------------------------------------------------------

# TODO: Distro versions from/to should be parameterized

headline "Changing the repositories"
ask "Change the repositories for distribution upgrade?"
sed -i 's/jessie/stretch/g' /etc/apt/sources.list.d/*

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Update APT package index
#-------------------------------------------------------------------------------------------------

headline "Update APT package index"
ask "Run: apt-get update?"
apt-get update

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Upgrade APT packages
#-------------------------------------------------------------------------------------------------

headline "Upgrade APT packages (current distribution)"
ask "Run: apt-get upgrade?"
apt-get upgrade

#-------------------------------------------------------------------------------------------------
# BEFORE distribution upgrade: Run the full dist upgrade 
#-------------------------------------------------------------------------------------------------

headline "Upgrade to another distribution"
ask "Run: apt-get dist-upgrade?"
apt-get dist-upgrade

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Autoremove unneccessary packages
#-------------------------------------------------------------------------------------------------

headline "Autoremoval of redundant packages" 
ask "Run: apt-get autoremove?"
sudo apt-get autoremove

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Run a full puppet run
#-------------------------------------------------------------------------------------------------

headline "Full Puppet run"
if ask "Run a full puppet run?"
    puppet agent -t
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

headline "Check for existence of a linux-image metapackage:"
dpkg -l "linux-image*" | grep ^ii | grep -i meta
ask

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Check for config files left after autoremove operation
#-------------------------------------------------------------------------------------------------

headline "List packages that retain config files after autoremove command:"
dpkg -l | awk '/^rc/ { print $2 }'
ask

echo
if ask "Remove these config files?"
    apt-get purge $(dpkg -l | awk '/^rc/ { print $2 }')
fi

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Check that avahi service is disabled
#-------------------------------------------------------------------------------------------------

headline "Check if avahi service is disabled (it should not be)"
systemctl list-unit-files | grep avahi

#-------------------------------------------------------------------------------------------------
# AFTER distribution upgrade: Reboot the machine
#-------------------------------------------------------------------------------------------------

headline "System reboot"
echo "IMPORTANT!! After restarting the machine check logs to ensure all services are up and running."
if ask "Reboot the machine?"
    reboot
fi
