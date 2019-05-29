#!/bin/bash
REPOSITORY_BASE=https://osm-download.etsi.org/repository/osm/debian
RELEASE=ReleaseSIX
REPOSITORY=stable
DOCKER_TAG=6

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

add_repo "deb [arch=amd64] $REPOSITORY_BASE/$RELEASE $REPOSITORY devops"
sudo DEBIAN_FRONTEND=noninteractive apt-get -q update
sudo DEBIAN_FRONTEND=noninteractive apt-get install osm-devops
/usr/share/osm-devops/installers/full_install_osm.sh -R $RELEASE -r $REPOSITORY -u $REPOSITORY_BASE -D /usr/share/osm-devops -t $DOCKER_TAG "$@"
