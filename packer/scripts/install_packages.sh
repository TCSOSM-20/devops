#!/bin/sh
sudo apt -y update && apt-get -y upgrade
sudo apt -y install git wget curl vim snapd lxd software-properties-common
sudo apt-get install -y apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -qq update
sudo apt-get install -y docker-ce
sudo groupadd -f docker
sudo usermod -aG docker $USER
