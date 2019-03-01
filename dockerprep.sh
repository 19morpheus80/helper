#!/bin/bash

# This file needs updating with some error checking and check docker group exists before attempting usermod.

echo "Updating system"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
apt-cache policy docker-ce
sudo apt-get install -y docker-ce

if getent group docker | grep &>/dev/null "\b${USER}\b"; then
  echo "User already in docker group."
else
  echo "Adding user to docker group.  You will need to re-authenticate (log out and back in again)."
  sudo usermod -aG docker ${USER}
fi

echo "Done"