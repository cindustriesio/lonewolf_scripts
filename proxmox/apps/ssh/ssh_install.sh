# !/bin/bash
# Description: This script will install and enable ssh on the system
# Version: 0.1
# Created by: Clark Industries IO 

# below command will Update package lists
sudo apt update

# below command will Upgrade the packages that can be upgraded
sudo apt upgrade -y

#install and enable ssh
sudo apt install openssh-server openssh-client -y

#add ssh to launch on system boot
sudo systemctl enable ssh

#allow SSH in firewall
sudo ufw allow ssh

# below command will Remove unnecessary packages and dependencies for good memory management
sudo apt autoremove -y

# below command will Clean package cache
sudo apt clean -y

# below command will Display system update status on terminal to know if the update and upgrade is successfull
echo "System updates and upgrades completed successfully."