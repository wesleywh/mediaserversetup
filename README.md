
# Raspberry PI w/ Plex & watchtower (setup_pi.sh)

## What does this script install?
- email/text alerts
  - ssmtp
  - mailutils
- docker-ce
  - apt-transport-https 
  - ca-certificates 
  - curl 
  - gnupg2 
  - software-properties-common 
  - watchtower docker (v2tec/watchtower:armhf-latest)
  - plex docker (lsioarmhf/plex:144)

## Removing things you don't want to install
You really don't need the email/text alerts section if you don't want it. Simply remove everything after the comment `Setup Email Alerts ` all the way to the comment: `Verify that USB drive is mounted`.

## How to use it
1. Copy this script onto your raspberry pi anywhere, it doesn't matter.

2. An external drive is expected to be mounted at `/mnt/library`. The script will not continue to run until that is mounted. 

3. There are a series of variables at the top of the file that you are expected to change in order to get the script to run. If they are not changed you will be presented with a warning until they are. They are all with the value `REPLACEME`.

4. When all the above is done you can run this script from anywhere with `sudo bash setup_pi.sh`.

NOTE: You can run this as many times as you want and it will never attempt to install anything that is already installed.
