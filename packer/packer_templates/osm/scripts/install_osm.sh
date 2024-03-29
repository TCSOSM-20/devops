#!/bin/bash
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
REPOSITORY_BASE=https://osm-download.etsi.org/repository/osm/debian
RELEASE=ReleaseSEVEN
REPOSITORY=stable
DOCKER_TAG=7

function usage(){
    echo -e "usage: $0 [OPTIONS]"
    echo -e "Install OSM from binaries or source code (by default, from binaries)"
    echo -e "  OPTIONS"
    echo -e "     -r <repo>:      use specified repository name for osm packages"
    echo -e "     -R <release>:   use specified release for osm binaries (deb packages, lxd images, ...)"
    echo -e "     -u <repo base>: use specified repository url for osm packages"
    echo -e "     -k <repo key>:  use specified repository public key url"
    echo -e "     -b <refspec>:   install OSM from source code using a specific branch (master, v2.0, ...) or tag"
    echo -e "                     -b master          (main dev branch)"
    echo -e "                     -b v2.0            (v2.0 branch)"
    echo -e "                     -b tags/v1.1.0     (a specific tag)"
    echo -e "                     ..."
    echo -e "     -s <stack name> user defined stack name, default is osm"
    echo -e "     -H <VCA host>   use specific juju host controller IP"
    echo -e "     -S <VCA secret> use VCA/juju secret key"
    echo -e "     -P <VCA pubkey> use VCA/juju public key file"
    echo -e "     -C <VCA cacert> use VCA/juju CA certificate file"
    echo -e "     -A <VCA apiproxy> use VCA/juju API proxy"
    echo -e "     --vimemu:       additionally deploy the VIM emulator as a docker container"
    echo -e "     --elk_stack:    additionally deploy an ELK docker stack for event logging"
    echo -e "     --pm_stack:     additionally deploy a Prometheus+Grafana stack for performance monitoring (PM)"
    echo -e "     -m <MODULE>:    install OSM but only rebuild the specified docker images (LW-UI, NBI, LCM, RO, MON, POL, KAFKA, MONGO, PROMETHEUS, KEYSTONE-DB, NONE)"
    echo -e "     -o <ADDON>:     ONLY (un)installs one of the addons (vimemu, elk_stack, pm_stack)"
    echo -e "     -D <devops path> use local devops installation path"
    echo -e "     -w <work dir>   Location to store runtime installation"
    echo -e "     -t <docker tag> specify osm docker tag (default is latest)"
    echo -e "     --nolxd:        do not install and configure LXD, allowing unattended installations (assumes LXD is already installed and confifured)"
    echo -e "     --nodocker:     do not install docker, do not initialize a swarm (assumes docker is already installed and a swarm has been initialized)"
    echo -e "     --nojuju:       do not juju, assumes already installed"
    echo -e "     --nodockerbuild:do not build docker images (use existing locally cached images)"
    echo -e "     --nohostports:  do not expose docker ports to host (useful for creating multiple instances of osm on the same host)"
    echo -e "     --nohostclient: do not install the osmclient"
    echo -e "     --uninstall:    uninstall OSM: remove the containers and delete NAT rules"
    echo -e "     --source:       install OSM from source code using the latest stable tag"
    echo -e "     --develop:      (deprecated, use '-b master') install OSM from source code using the master branch"
    echo -e "     --soui:         install classic build of OSM (Rel THREE v3.1, based on LXD containers, with SO and UI)"
    echo -e "     --lxdimages:    (only for Rel THREE with --soui) download lxd images from OSM repository instead of creating them from scratch"
    echo -e "     --pullimages:   pull/run osm images from docker.io/opensourcemano"
    echo -e "     -l <lxd_repo>:  (only for Rel THREE with --soui) use specified repository url for lxd images"
    echo -e "     -p <path>:      (only for Rel THREE with --soui) use specified repository path for lxd images"
    echo -e "     --nat:          (only for Rel THREE with --soui) install only NAT rules"
    echo -e "     --noconfigure:  (only for Rel THREE with --soui) DO NOT install osmclient, DO NOT install NAT rules, DO NOT configure modules"
    echo -e "     --showopts:     print chosen options and exit (only for debugging)"
    #echo -e "     --clean_volumes To clear all the mounted volumes from docker swarm"
    echo -e "     -y:             do not prompt for confirmation, assumes yes"
    echo -e "     -h / --help:    print this help"
}

add_repo() {
  REPO_CHECK="^$1"
  grep "${REPO_CHECK/\[arch=amd64\]/\\[arch=amd64\\]}" /etc/apt/sources.list > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    need_packages_lw="software-properties-common apt-transport-https"
    echo -e "Checking required packages: $need_packages_lw"
    dpkg -l $need_packages_lw &>/dev/null \
      || ! echo -e "One or several required packages are not installed. Updating apt cache requires root privileges." \
      || sudo apt-get -q update \
      || ! echo "failed to run apt-get update" \
      || exit 1
    dpkg -l $need_packages_lw &>/dev/null \
      || ! echo -e "Installing $need_packages_lw requires root privileges." \
      || sudo apt-get install -y $need_packages_lw \
      || ! echo "failed to install $need_packages_lw" \
      || exit 1
    wget -qO - $REPOSITORY_BASE/$RELEASE/OSM%20ETSI%20Release%20Key.gpg | sudo apt-key add -
    sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y "$1" && sudo DEBIAN_FRONTEND=noninteractive apt-get update
    return 0
  fi

  return 1
}

clean_old_repo() {
dpkg -s 'osm-devops' &> /dev/null
if [ $? -eq 0 ]; then
  # Clean the previous repos that might exist
  sudo sed -i "/osm-download.etsi.org/d" /etc/apt/sources.list
fi
}

while getopts ":b:r:c:k:u:R:l:p:D:o:m:H:S:s:w:t:U:P:A:-: hy" o; do
    case "${o}" in
        r)
            REPOSITORY="${OPTARG}"
            ;;
        R)
            RELEASE="${OPTARG}"
            ;;
        u)
            REPOSITORY_BASE="${OPTARG}"
            ;;
        t)
            DOCKER_TAG="${OPTARG}"
            ;;
        -)
            [ "${OPTARG}" == "help" ] && usage && exit 0
	    ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            usage && exit 1
            ;;
        \?)
            echo -e "Invalid option: '-$OPTARG'\n" >&2
            usage && exit 1
            ;;
        h)
            usage && exit 0
            ;;
        *)
            ;;
    esac
done

clean_old_repo

add_repo "deb [arch=amd64] $REPOSITORY_BASE/$RELEASE $REPOSITORY devops"
sudo DEBIAN_FRONTEND=noninteractive apt-get -q update
sudo DEBIAN_FRONTEND=noninteractive apt-get install osm-devops
#FIXME: sudo DEBIAN_FRONTEND=noninteractive apt-get install -y osm-devops

#--- FIXME: Workaround until patch for unattended install comes with default installer
sudo wget -O /usr/share/osm-devops/installers/full_install_osm.sh "https://osm.etsi.org/gitweb/?p=osm/devops.git;a=blob_plain;f=installers/full_install_osm.sh;hb=4205c192a9b6c2e30459987491e02a44ca3695d6"
sudo chmod +x /usr/share/osm-devops/installers/full_install_osm.sh
#--- End of workaround

/usr/share/osm-devops/installers/full_install_osm.sh -R $RELEASE -r $REPOSITORY -u $REPOSITORY_BASE -D /usr/share/osm-devops -t $DOCKER_TAG "$@"

############################################
# OSM Install without workarounds
############################################
#wget https://osm-download.etsi.org/ftp/osm-7.0-seven/install_osm.sh
#chmod +x install_osm.sh
##./install_osm.sh -c k8s --k8s_monitor --elk_stack 2>&1 | tee osm_install_log.txt
##./install_osm.sh -c k8s --k8s_monitor 2>&1 | tee osm_install_log.txt
#./install_osm.sh 2>&1 | tee osm_install_log.txt
############################################

# Saves the IP address used during install, in case the VM needed to be reinstantiated later with a different IP address
sudo mkdir -p  ${STATE_FOLDER}
sudo chmod a+r ${STATE_FOLDER}
DEFAULT_IF=$(route -n |awk '$1~/^0.0.0.0/ {print $8}')
DEFAULT_IP=$(ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}')
sudo su - -c "echo ${DEFAULT_IP} > ${STATE_FOLDER}/oldIPaddress.txt"
