#!/bin/bash

function ask {
    while true; do
        echo
        read -p "Fortsätt? (Y/n): " yn
        case $yn in
            [Yy]* ) echo; return 1;;
            [Nn]* ) exit;;
            * ) echo "Svara Y eller n";;
        esac
    done
}

function headline() {
    clear
    echo
    echo "################################################"
    echo "# $1"
    echo "################################################"
}

# Kolla ifall det finns en datorbas..
databases="mariadb postgresql.service mongod.service mysql"
for i in $databases
do
    if $( systemctl status $i > /dev/null 2>&1 )
    then
        echo ERROR: Det finns en eller fler databaser som kör i maskinen.. ta BACKUP 1>&2
	echo $i
        exit 1
    fi
done


######################################
# Vad gör vi innan en uppgradering?
######################################
headline "Har du tagit en backup? OTROLIGT VIKTIGT att göra!"
ask

######################################
# Är den satt på shecudles downtime på OP5?
######################################
headline "Har du tagit ner den ifrån OP5***??"
ask


headline "Se till att det finns utrymme i hårddisken:"
#apt-get -o APT::Get::Trivial-Only=true dist-upgrade | awk '/After this operation/'
checkDisk=`df --out=target,avail / | awk ' NR==2 {print $2}'`
checkDiskH=`df -h --out=target,avail / | awk ' NR==2 {print $2}'`
if [ "$checkDisk" -gt "2000000" ];then
    echo "JA=$checkDiskH"
else
    echo "OPS: MINDRE ÄN 2GB KVAR PÅ HÅRDDISKEN"
    exit 1
fi
ask

headline "Kolla vilken puppet server den går mot:"
newPuppet=$(cat /etc/puppetlabs/puppet/puppet.conf | grep server | awk '{print $3}')
oldPuppet="prod-int-puppet1.skolverket.se"
if [ $newPuppet == "prod-int-pe1.skolverket.se" ]; then
    echo "Du är på rätt puppet server ($newPuppet)!"
else
    echo "Gammal puppet server ($oldPuppet): <scriptet avslutas>"
    exit 1
fi
ask

headline "Kolla ifall packet är satta i Hold:"
dpkg --get-selections "*" > ~/curr-pkgs.txt
ask

headline "Kör puppet med --noop: "
echo
read -p "(Y/n): " 
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "continue"
else
    puppet agent -t --noop
fi

echo
echo "################################################"
echo "# Kör en full puppet run: "
echo "################################################"
read -p "(Y/n): "
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    puppet agent -t
    clear
fi

headline "Uppdatera paketen innan man kör självaste uppgraderingen till Debian9:"
ask
apt-get update

headline "Kör en apt-get upgrade:"
ask
apt-get upgrade

headline "Kör en apt-get dist-upgrade:"
ask
apt-get dist-upgrade

headline "Lista och stäng av möjliga tjänster som kan vara igång:"
services="auth-entrust jenkins puppet pxp-agent mcollective mariadb postgresql.service mongod mysql solr ci session-c1.scope kibana apache apache2 nginx unicorn prometheus http tomcat susanavet2 jboss gitlab-runsvdir.service slapd exim4"
for i in $services
do
    if $( systemctl status $i > /dev/null 2>&1 )
    then
        read -p "Vill du stänga av $i? "
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Avslutar skript... Tjänster MÅSTE stängas av innan en uppgradering"
            exit 1
        else
            systemctl stop $i
        fi
    fi
done

headline "Vi behöver andra på repositories innan uppgraderingen:"
ask
sed -i 's/jessie/stretch/g' /etc/apt/sources.list.d/*

headline "UPPGRADERINGEN"
ask
apt-get update

headline "apt-get upgrade:"
ask
apt-get upgrade

headline "apt-get dist-upgrade:"
ask
apt-get dist-upgrade

######################################
# Vad gör vi efter uppgraderingen?:
######################################
headline "Kör apt-get autoremove:"
ask
sudo apt-get autoremove

echo
echo "################################################"
echo "# Kör en full puppet run: "
echo "################################################"
read -p "(Y/n): "
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    puppet agent -t
fi

headline "Kolla status på eventuella paket som inte har installerats rätt:"
dpkg --audit
ask

headline "Kolla ifall det finns en linux-image metapackage:"
dpkg -l "linux-image*" | grep ^ii | grep -i meta
ask

headline "Vi listar paker som fortfarande har configurations filer kvar efter bottragningen (autoremove commandot):"
dpkg -l | awk '/^rc/ { print $2 }'
ask

headline "Vill du ta bort dessa konfigurations filer? (Y/n): "
echo
read -p "(Y/n): "
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    apt-get purge $(dpkg -l | awk '/^rc/ { print $2 }')
fi


headline "Se så att avahi är disabled"
systemctl list-unit-files | grep avahi

######################################
# Done: 
######################################

#reboot
headline "Starta om maskinen"
echo "OBS OBS OBS!! Efter att man startat om maskinen så MÅSTE man kolla diverse loggar och verkligen se till att applikationen fungerar rätt"
ask
reboot
