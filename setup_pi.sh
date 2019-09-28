#!/bin/bash

# Another startup script can be found at: /etc/init.d/startup.sh

# Helpful Vars
IPADDRESS=`ifconfig eth0 | perl -nle 's/dr:(\S+)/print $1/e'`
SMTP_AUTH_USER=REPLACEME
SMTP_AUTH_PASS=REPLACEME
SMTP_MAILHUB=REPLACEME
SMTP_ALERT_EMAIL=REPLACEME
SMTP_FROM_EMAIL=REPLACEME
RELEASE_VER=`lsb_release -cs`

echo "Raspbian Release Version: $RELEASE_VER"

if [ $? -eq 0 ]; then
	echo "IPADDRESS: $IPADDRESS"
else
	echo "Failed to find IP address"
	exit 1
fi
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
	echo "SSMTP not installed, installing it..."
	sudo apt-get install ssmtp mailutils -y
else
	echo "SSMTP already installed, skipping..."
fi
smtp_file_loc="/etc/ssmtp/ssmtp.conf"
echo "Modifying $smtp_file_loc..."
echo " * Adding mailhub line..."
sed -i "s/mailhub=.*/mailhub=${SMTP_MAILHUB}/g" $smtp_file_loc
sed -i "s/#FromLineOverride=NO/FromLineOverride=YES/g" $smtp_file_loc

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
	echo "SMTP successfully installed!"
	echo "Use it like so: echo \"Hello indox!\" | mail -s \"Test\" -a \"FROM: firstname lastname <$SMTP_FROM_EMAIL>\" $SMTP_ALERT_EMAIL"
	echo "You can also use this to send text message alerts!"
	echo "For example if you're on a metro pcs plan you can email <YOUR_PHONE_NUMBER>@mymetropcs.com"
	echo "NOTE: If your from email is a gmail you need to enable insecure apps to use this, maybe not the best?"
	echo "I used amazon ses (AWS SES) service to send secure emails."
	echo "------------------------------"
else
	echo "SMTP Failed to install."
	exit 1
fi

# Verify that USB drive is mounted
LIBMOUNTED=False
for i in {1..15}; do
	if grep -qs '/mnt/library' /proc/mounts; then
		echo "Library successfully mounted!"
		LIBMOUNTED="True"
		break
	else
		echo "Library not yet mounted at /mnt/library, waiting 5s..."
		sleep 5
	fi
done
if [ "$LIBMOUNTED" = "False" ]; then
	echo "Library failed to mount, exiting program"
	exit 1
fi

# Install/Start Docker Service
docker_status=`sudo service docker status`
if [ $? -eq 0 ]; then
	echo "Docker installed, making sure it's on..."
	if [ "$(systemctl is-active docker)" != "active" ]; then
		echo "Docker not started, starting it..."
		sudo service docker start
	else
		echo "Docker is on, continuing..."
	fi
else
	echo "Docker not installed, installing now..."
	sudo grep -qxF "deb https://download.docker.com/linux/debian $(lsb_release -cs) stable" /etc/apt/sources.list || \
		echo "deb https://download.docker.com/linux/debian $(lsb_release -cs) stable" >> /etc/apt/sources.list
	echo "Added docker download source"
	echo "------------------------------"
	cat /etc/apt/sources.list
	echo "------------------------------"
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
	sudo apt-get update -y
	sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
	sudo apt-key fingerprint 0EBFCD88
	sudo apt-key update -y
	sudo apt-get install docker-ce -y
	docker info
	if [ $? -eq 0 ]; then
		echo "-----------------------------------"
		echo "Docker successfully installed!"
		echo "-----------------------------------"
	else
		sudo service docker start
		docker info
	fi
fi

# Setup WatchTower docker for auto updating dockers
echo "Starting \"WatchTower\" docker..."
if [ ! "$(sudo docker ps -a | grep -c watchtower)" -eq 0 ]; then
	sudo docker stop watchtower && sudo docker rm watchtower
fi
sudo docker run -d \
	--name watchtower \
	-v /var/run/docker.sock:/var/run/docker.sock \
	v2tec/watchtower:armhf-latest
if [ ! $? -eq 0 ]; then
	echo "Failed to start watchtower docker, exiting."
	exit 1
fi

# Setup Plex Docker
# NOTE: The default plex docker will return an exec issue, have to use a custom one
echo "Starting \"Plex\" docker..."
if [ ! "$(sudo docker ps -a | grep -c plex)" -eq 0 ]; then
	sudo docker stop plex && sudo docker rm plex
fi
sudo docker run -d \
	--name plex \
	--net=host \
	--restart=always \
	-v /mnt/library/data:/data \
	-v /mnt/library/transcode:/transcode \
	-v /mnt/library/config:/config \
	-e TZ="US/Mountain" \
	-e ADVERTISE_IP="http://$IPADDRESS:32400/" \
	-e PUID=0 \
	-e PGID=0 \
	lsioarmhf/plex:144

if [ ! $? -eq 0 ]; then
	echo "Failed to start plex server, exiting."
	exit 1
fi
