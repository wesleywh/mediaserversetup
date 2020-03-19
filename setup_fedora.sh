#!/bin/bash

# Script used to setup fedora with various things meant for a home media server

#Helpful Vars
INSTALL_STEAMCACHE="TRUE"
INSTALL_SAMBA="TRUE"

SAMBA_USER="<MY_SAMBA_USER>"
SAMBA_PASS="<MY_SAMBA_PASS>"

SMTP_AUTH_USER="<AWS_SES_AUTH_USER>"
SMTP_AUTH_PASS="<AWS_SES_AUTH_PASS>"
SMTP_MAILHUB="<AWS_SES_URL>"
SMTP_ALERT_EMAIL="<EMAIL_TO_ALERT>"
SMTP_FROM_EMAIL="<EMAIL_TO_SEND_FROM>"

HOME_DIR="$(cd ~/ && pwd)"
RELEASE_VER=`cat /etc/fedora-release | cut -d' ' -f3 | tr -d '\n'`

PLEX_LIB="<PLEX_LIB_DIR>"
PLEX_META="$HOME_DIR/plex"
PLEX_ISMOUNT="TRUE"

ENABLE_SSH="FALSE"
SSH_PORT="777"
SSH_AUTH_KEYS_LOC="$HOME_DIR/.ssh/authorized_keys"
SSH_KEY_LOC="$HOME_DIR/.ssh/mediaserverkey"

IPADDRESS="`ip addr show eth0 | grep "inet" | cut -d: -f2 | awk '{print $2}' | cut -d/ -f1 | tr -d '\n'`"
if [ "$IPADDRESS" == "" ]; then
	IPADDRESS="`ip addr show enp3s0 | grep "inet" | cut -d: -f2 | awk '{print $2}' | cut -d/ -f1 | tr -d '\n'`"
fi
echo "------------------------------"
echo "IPADDRESS: $IPADDRESS"
echo "RELEASE VERSION: $RELEASE_VER"
echo "------------------------------"

if [ "$SMTP_AUTH_USER" = "REPLACEME" ]; then
	echo "Did not replace the SMTP_USER variable in this script. Please open the script and replace this."
	exit 1
fi
if [ "$SMTP_AUTH_PASS" = "REPLACEME" ]; then
	echo "Did not replace the SMTP_PASS variable in this script. Please open the script and replace this."
	exit 1
fi
if [ "$SMTP_MAILHUB" = "REPLACEME" ]; then
	echo "Did not replace the SMTP_EMAIL variable in this script. Please open this script and replace this."
	exit 1
fi
if [ "$SMTP_ALERT_EMAIL" = "REPLACEME" ]; then
	echo "Did not replace the SMTP_ALERT_EMAIL variables in this script. Please open this script and replace this."
	exit 1
fi

# Setup Email Alerts
echo "Setting up email alerts..."
ssmtp --version
if [ ! $? -eq 0 ]; then
	echo "ssmtp not installed, installing it..."
	sudo dnf install ssmtp mailx -y
else
	echo "ssmtp already installed, skipping..."
fi
smtp_file_loc="/etc/ssmtp/ssmtp.conf"
echo "Modifying $smtp_file_loc..."
echo " * Modifying mailhub line..."
sed -i "s/mailhub=.*/mailhub=${SMTP_MAILHUB}/g" $smtp_file_loc

echo "Modifying FromLineOverride line..."
sed -i "s/FromLineOverride=NO/FromLineOverride=YES/g" $smtp_file_loc
sed -i "s/#FromLineOverride=YES/FromLineOverride=YES/g" $smtp_file_loc

if [ $(cat $smtp_file_loc | grep -c "AuthUser=") -gt 0 ]; then
	echo " * AuthUser line exists, updating..."
	sed -i "s/AuthUser=.*/AuthUser=$SMTP_AUTH_USER/g" $smtp_file_loc
else
	echo " * Missing AuthUser line, adding it..."
	echo "AuthUser=$SMTP_AUTH_USER" >> $smtp_file_loc
fi

if [ $(cat $smtp_file_loc | grep -c "AuthPass=") -gt 0 ]; then
	echo " * AuthPass line exists, updating..."
	sed -i "s/AuthPass=.*//g" $smtp_file_loc
	echo "AuthPass=$SMTP_AUTH_PASS" >> $smtp_file_loc
else
	echo " * Missing AuthPass line, adding it..."
	echo "AuthPass=$SMTP_AUTH_PASS" >> $smtp_file_loc
fi

if [ $(cat $smtp_file_loc | grep -c "UseSTARTTLS=YES") -eq 0 ]; then
	echo " * Missing UseSTARTTLS line, adding it..."
	echo "UseSTARTTLS=YES" >> $smtp_file_loc
fi

if [ $(cat $smtp_file_loc | grep -c "UseTLS=YES") -eq 0 ]; then
	echo " * Missing UseTLS line, adding it..."
	echo "UseTLS=YES" >> $smtp_file_loc
fi
ssmtp --version
if [ $? -eq 0 ]; then
	echo "------------------------------"
	echo "SSMTP successfully installed!"
	echo "Use it like so: echo \"Hello indox!\" | mail -s \"Test\" -r $SMTP_FROM_EMAIL $SMTP_ALERT_EMAIL"
	echo "You can also use this to send text message alerts!"
	echo "For example if you're on a metro pcs plan you can email <YOUR_PHONE_NUMBER>@mymetropcs.com"
	echo "NOTE: If your from email is a gmail you need to enable insecure apps to use this, maybe not the best?"
	echo "I used amazon ses (AWS SES) service to send secure emails."
	echo "------------------------------"
else
	echo "ssmtp Failed to install."
	exit 1
fi

#Setup SSH access
if [ "$ENABLE_SSH" == "TRUE" ]; then
	echo "Modifying sshd_config file..."
	ssh_conf = "/etc/ssh/sshd_config"
	echo "Enabling port: $SSH_PORT..."
	sed -i "s/Port .*/Port ${SSH_PORT}/g" $ssh_conf
	sed -i "s/#Port .*/Port ${SSH_PORT}/g" $ssh_conf
	if [ $(cat $ssh_conf | grep -c "PermitRootLogin") -gt 0 ]; then
		echo "Adding \"PermitRootLogin no\" line..."
		echo "PermitRootLogin no" >> $ssh_conf
	else
		echo "Modifying \"PermitRootLogin\" to say \"no\"..."
		sed -i "s/#PermitRootLogin .*/PermitRootLogin no/g" $ssh_conf
		sed -i "s/PermitRootLogin .*/PermitRootLogin no/g" $ssh_conf
	fi
	if [ $(cat $ssh_conf | grep -c "AuthorizedKeysFile") -gt 0 ]; then
		echo "Adding \"AuthorizedKeysFile	$SSH_AUTH_KEYS_LOC\" line..."
		echo "AuthorizedKeysFile	$SSH_AUTH_KEYS_LOC" >> $$ssh_conf
	else
		echo "Modifying \"AuthorizedKeysFile\" line..."
		sed -i "s/AuthorizedKeysFile	.*/AuthorizedKeysFile	$SSH_AUTH_KEYS_LOC/g" $ssh_conf
		sed -i "s/#AuthorizedKeysFile	.*/AuthorizedKeysFile	$SSH_AUTH_KEYS_LOC/g" $ssh_conf
	fi
	if [ $(cat $ssh_conf | grep -c "PasswordAuthentication") -gt 0 ]; then
		echo "Adding \"PasswordAuthentication no\" line..."
		echo "PasswordAuthentication no" >> $$ssh_conf
	else 
		echo "Modifying \"PasswordAuthentication\" line..."
		sed -i "s/PasswordAuthentication.*/PasswordAuthentication no/g" $ssh_conf
		sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/g" $ssh_conf
	fi
	sudo semanage port -a -t ssh_port_t -p tcp $SSH_PORT
	sudo systemctl enable sshd
	sudo service sshd start
fi

# Install/Start Docker Service
docker_status=`sudo service docker status`
if [ $? -eq 0 ]; then
	echo "Docker installed, making sure it's on..."
	if [ "$(systemctl is-active docker)" != "active" ]; then
		echo "Docker not started, starting it..."
		sudo service docker start
	else
		echo "-----------------------------"
		echo "Docker is on, continuing..."
		echo "-----------------------------"
	fi
else
	echo "Docker not installed, installing now..."
	sudo grep -qxF "deb https://download.docker.com/linux/fedora $RELEASE_VER stable" /etc/apt/sources.list || \
		echo "deb https://download.docker.com/linux/fedora $RELEASE_VER stable" >> /etc/apt/sources.list
	echo "Added docker download source"
	echo "------------------------------"
	cat /etc/apt/sources.list
	echo "------------------------------"
	curl -fsSL https://download.docker.com/linux/fedora/gpg | sudo apt-key add -
	sudo apt-get update -y
	sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
	sudo apt-key fingerprint 0EBFCD88
	sudo apt-key update -y
	sudo apt-get install docker-ce -y
	docker info
	if [ $? -eq 0 ]; then
		echo "-----------------------------------"
		echo "Docker successfully installed!"
		sudo service docker start
		docker info
		echo "-----------------------------------"
	else
		echo "-----------------------"
		echo "ERROR: Docker failed to install!"
		exit 1
		echo "-----------------------"
	fi
fi

# Verify that USB drive is mounted (If the PLEX_ISMOUNT=TRUE)
if [ "$PLEX_ISMOUNT" == "TRUE" ]; then
	LIBMOUNTED=False
	for i in {1..3}; do
		if grep -qs "$PLEX_LIB" /proc/mounts; then
			echo "Library successfully mounted!"
			LIBMOUNTED="True"
			break
		else
			echo "Library not yet mounted at $PLEX_LIB, waiting 5s (run \"lsblk\" or "sudo fdisk -l" to show whats available)..."
			echo " -- Mount device EX: \"sudo mount /dev/sdb $PLEX_LIB\""
			sleep 5
		fi
	done
	if [ "$LIBMOUNTED" = "False" ]; then
		echo "Library failed to mount, exiting program"
		exit 1
	fi
fi

# ---------------------- DOCKERS -------------------------
# Setup WatchTower docker for auto updating dockers
echo "Starting \"WatchTower\" docker..."
if [ ! "$(sudo docker ps -a | grep -c watchtower)" -eq 0 ]; then
	sudo docker stop watchtower && sudo docker rm watchtower
fi
sudo docker run -d \
	--name watchtower \
	--restart=always \
	-v /var/run/docker.sock:/var/run/docker.sock \
	v2tec/watchtower:latest
if [ ! $? -eq 0 ]; then
	echo "Failed to start watchtower docker, exiting."
	exit 1
fi

# Setup Plex Docker
echo "Starting \"Plex\" docker..."
if [ ! "$(sudo docker ps -a | grep -c plex)" -eq 0 ]; then
	sudo docker stop plex && sudo docker rm plex
fi
sudo docker run -d \
	--name plex \
	--net=host \
	--restart=always \
	-v $PLEX_LIB/data:/data \
	-v $PLEX_META/transcode:/transcode \
	-v $PLEX_META/config:/config \
	-e TZ="US/Mountain" \
	-e ADVERTISE_IP="http://$IPADDRESS:32400/" \
	-e PUID=0 \
	-e PGID=0 \
	linuxserver/plex:latest

if [ ! $? -eq 0 ]; then
	echo "Failed to start plex server, exiting."
	exit 1
fi

# Setup Samba Docker
if [ "$INSTALL_SAMBA" == "TRUE" ]; then
	echo "Starting \"samba\" docker..."
	if [ ! -d "$HOME_DIR/share" ]; then 
		echo "Making directory: $HOME_DIR/share"
		mkdir -p $HOME_DIR/share
	fi
	if [ ! "$(sudo docker ps -a | grep -c samba)" -eq 0 ]; then
		sudo docker stop samba && sudo docker rm samba
	fi

	sudo docker run -d --restart always \
	--name samba -p 139:139 -p 445:445 \
	--hostname=hawsmedia \
	--restart always \
	-v $HOME_DIR/share:/mount -d \
	-v $PLEX_LIB:/plex_media \
	dperson/samba:latest \
	-n \
	-u "$SAMBA_USER;$SAMBA_PASS" -W \
	-s "PlexMedia;/plex_media;yes;no;no;$SAMBA_USER;$SAMBA_USER;Plex Media Server" \
	-s "FileServer;/mount/files;yes;no;no;$SAMBA_USER;$SAMBA_USER;File Server"

	if [ ! $? -eq 0 ]; then
		echo "Failed to start \"samba\" docker, exiting..."
		exit 1
	fi
fi


# Setup Auto cleanup docker crontab
if [ $(sudo cat /etc/crontab | grep -c "/home/$(whoami)/crontab_job.sh") -lt 1 ]; then
	echo "0 0 1 * * /home/$(whoami)/crontab_job.sh" | sudo tee -a /etc/crontab > /dev/null
fi