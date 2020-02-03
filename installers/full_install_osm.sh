#!/bin/bash
#   Copyright 2016 Telefónica Investigación y Desarrollo S.A.U.
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
    echo -e "     -c <orchestrator> deploy osm services using container <orchestrator>. Valid values are <k8s> or <swarm>.  If -c is not used then osm will be deployed using default orchestrator. When used with --uninstall, osm services deployed by the orchestrator will be uninstalled"
    echo -e "     -s <stack name> or <namespace>  user defined stack name when installed using swarm or namespace when installed using k8s, default is osm"
    echo -e "     -H <VCA host>   use specific juju host controller IP"
    echo -e "     -S <VCA secret> use VCA/juju secret key"
    echo -e "     -P <VCA pubkey> use VCA/juju public key file"
    echo -e "     -C <VCA cacert> use VCA/juju CA certificate file"
    echo -e "     -A <VCA apiproxy> use VCA/juju API proxy"
    echo -e "     --vimemu:       additionally deploy the VIM emulator as a docker container"
    echo -e "     --elk_stack:    additionally deploy an ELK docker stack for event logging"
    echo -e "     -m <MODULE>:    install OSM but only rebuild the specified docker images (LW-UI, NBI, LCM, RO, MON, POL, KAFKA, MONGO, PROMETHEUS, PROMETHEUS-CADVISOR, KEYSTONE-DB, NONE)"
    echo -e "     -o <ADDON>:     ONLY (un)installs one of the addons (vimemu, elk_stack)"
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
    echo -e "     --pullimages:   pull/run osm images from docker.io/opensourcemano"
    echo -e "     --k8s_monitor:  install the OSM kubernetes moitoring with prometheus and grafana"
#    echo -e "     --reconfigure:  reconfigure the modules (DO NOT change NAT rules)"
#    echo -e "     --update:       update to the latest stable release or to the latest commit if using a specific branch"
    echo -e "     --showopts:     print chosen options and exit (only for debugging)"
    echo -e "     -y:             do not prompt for confirmation, assumes yes"
    echo -e "     -h / --help:    print this help"
}

# takes a juju/accounts.yaml file and returns the password specific
# for a controller. I wrote this using only bash tools to minimize
# additions of other packages
function parse_juju_password {
   password_file="${HOME}/.local/share/juju/accounts.yaml"
   local controller_name=$1
   local s='[[:space:]]*' w='[a-zA-Z0-9_-]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $password_file |
   awk -F$fs -v controller=$controller_name '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         if (match(vn,controller) && match($2,"password")) {
             printf("%s",$3);
         }
      }
   }'
}

function generate_secret() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32
}

function remove_volumes() {
    if [ -n "$KUBERNETES" ]; then
        k8_volume=$1
        echo "Removing ${k8_volume}"
        $WORKDIR_SUDO rm -rf ${k8_volume}
    else
        stack=$1
        volumes="mongo_db mon_db osm_packages ro_db pol_db prom_db ro"
        for volume in $volumes; do
            sg docker -c "docker volume rm ${stack}_${volume}"
        done
    fi
}

function remove_network() {
    stack=$1
    sg docker -c "docker network rm net${stack}"
}

function remove_iptables() {
    stack=$1
    if [ -z "$OSM_VCA_HOST" ]; then
        OSM_VCA_HOST=`sg lxd -c "juju show-controller ${stack}"|grep api-endpoints|awk -F\' '{print $2}'|awk -F\: '{print $1}'`
        [ -z "$OSM_VCA_HOST" ] && FATAL "Cannot obtain juju controller IP address"
    fi

    if [ -z "$DEFAULT_IP" ]; then
        DEFAULT_IF=`route -n |awk '$1~/^0.0.0.0/ {print $8}'`
        [ -z "$DEFAULT_IF" ] && FATAL "Not possible to determine the interface with the default route 0.0.0.0"
        DEFAULT_IP=`ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}'`
        [ -z "$DEFAULT_IP" ] && FATAL "Not possible to determine the IP address of the interface with the default route"
    fi

    if sudo iptables -t nat -C PREROUTING -p tcp -m tcp -d $DEFAULT_IP --dport 17070 -j DNAT --to-destination $OSM_VCA_HOST; then
        sudo iptables -t nat -D PREROUTING -p tcp -m tcp -d $DEFAULT_IP --dport 17070 -j DNAT --to-destination $OSM_VCA_HOST
        sudo netfilter-persistent save
    fi
}

function remove_stack() {
    stack=$1
    if sg docker -c "docker stack ps ${stack}" ; then
        echo -e "\nRemoving stack ${stack}" && sg docker -c "docker stack rm ${stack}"
        COUNTER=0
        result=1
        while [ ${COUNTER} -lt 30 ]; do
            result=$(sg docker -c "docker stack ps ${stack}" | wc -l)
            #echo "Dockers running: $result"
            if [ "${result}" == "0" ]; then
                break
            fi
            let COUNTER=COUNTER+1
            sleep 1
        done
        if [ "${result}" == "0" ]; then
            echo "All dockers of the stack ${stack} were removed"
        else
            FATAL "Some dockers of the stack ${stack} could not be removed. Could not clean it."
        fi
        sleep 5
    fi
}

#removes osm deployments and services
function remove_k8s_namespace() {
    kubectl delete ns $1
}

#Uninstall lightweight OSM: remove dockers
function uninstall_lightweight() {
    if [ -n "$INSTALL_ONLY" ]; then
        if [ -n "$INSTALL_ELK" ]; then
            echo -e "\nUninstalling OSM ELK stack"
            remove_stack osm_elk
            $WORKDIR_SUDO rm -rf $OSM_DOCKER_WORK_DIR/osm_elk
        fi
    else
        echo -e "\nUninstalling OSM"
        if [ -n "$KUBERNETES" ]; then
            if [ -n "$K8S_MONITOR" ]; then
                # uninstall OSM MONITORING
                uninstall_k8s_monitoring
            fi
            remove_k8s_namespace $OSM_STACK_NAME
        else

            remove_stack $OSM_STACK_NAME
            remove_stack osm_elk
        fi
        echo "Now osm docker images and volumes will be deleted"
        newgrp docker << EONG
        docker image rm ${DOCKER_USER}/ro:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/lcm:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/light-ui:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/keystone:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/nbi:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/mon:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/pol:${OSM_DOCKER_TAG}
        docker image rm ${DOCKER_USER}/osmclient:${OSM_DOCKER_TAG}
EONG

        if [ -n "$KUBERNETES" ]; then
            OSM_NAMESPACE_VOL="${OSM_HOST_VOL}/${OSM_STACK_NAME}"
            remove_volumes $OSM_NAMESPACE_VOL
        else
            remove_volumes $OSM_STACK_NAME
            remove_network $OSM_STACK_NAME
        fi
        remove_iptables $OSM_STACK_NAME
        echo "Removing $OSM_DOCKER_WORK_DIR"
        $WORKDIR_SUDO rm -rf $OSM_DOCKER_WORK_DIR
        sg lxd -c "juju destroy-controller --destroy-all-models --yes $OSM_STACK_NAME"
    fi
    echo "Some docker images will be kept in case they are used by other docker stacks"
    echo "To remove them, just run 'docker image prune' in a terminal"
    return 0
}

#Configure NAT rules, based on the current IP addresses of containers
function nat(){
    echo -e "\nChecking required packages: iptables-persistent"
    dpkg -l iptables-persistent &>/dev/null || ! echo -e "    Not installed.\nInstalling iptables-persistent requires root privileges" || \
    sudo apt-get -yq install iptables-persistent
    echo -e "\nConfiguring NAT rules"
    echo -e "   Required root privileges"
    sudo $OSM_DEVOPS/installers/nat_osm
}

function FATAL(){
    echo "FATAL error: Cannot install OSM due to \"$1\""
    exit 1
}

function install_lxd() {
    sudo apt-get update
    sudo apt-get install -y lxd
    newgrp lxd
    lxd init --auto
    lxd waitready
    lxc network create lxdbr0 ipv4.address=auto ipv4.nat=true ipv6.address=none ipv6.nat=false
    DEFAULT_INTERFACE=$(route -n | awk '$1~/^0.0.0.0/ {print $8}')
    DEFAULT_MTU=$(ip addr show $DEFAULT_INTERFACE | perl -ne 'if (/mtu\s(\d+)/) {print $1;}')
    lxc profile device set default eth0 mtu $DEFAULT_MTU
    #sudo systemctl stop lxd-bridge
    #sudo systemctl --system daemon-reload
    #sudo systemctl enable lxd-bridge
    #sudo systemctl start lxd-bridge
}

function ask_user(){
    # ask to the user and parse a response among 'y', 'yes', 'n' or 'no'. Case insensitive
    # Params: $1 text to ask;   $2 Action by default, can be 'y' for yes, 'n' for no, other or empty for not allowed
    # Return: true(0) if user type 'yes'; false (1) if user type 'no'
    read -e -p "$1" USER_CONFIRMATION
    while true ; do
        [ -z "$USER_CONFIRMATION" ] && [ "$2" == 'y' ] && return 0
        [ -z "$USER_CONFIRMATION" ] && [ "$2" == 'n' ] && return 1
        [ "${USER_CONFIRMATION,,}" == "yes" ] || [ "${USER_CONFIRMATION,,}" == "y" ] && return 0
        [ "${USER_CONFIRMATION,,}" == "no" ]  || [ "${USER_CONFIRMATION,,}" == "n" ] && return 1
        read -e -p "Please type 'yes' or 'no': " USER_CONFIRMATION
    done
}

function install_osmclient(){
    CLIENT_RELEASE=${RELEASE#"-R "}
    CLIENT_REPOSITORY_KEY="OSM%20ETSI%20Release%20Key.gpg"
    CLIENT_REPOSITORY=${REPOSITORY#"-r "}
    CLIENT_REPOSITORY_BASE=${REPOSITORY_BASE#"-u "}
    key_location=$CLIENT_REPOSITORY_BASE/$CLIENT_RELEASE/$CLIENT_REPOSITORY_KEY
    curl $key_location | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=amd64] $CLIENT_REPOSITORY_BASE/$CLIENT_RELEASE $CLIENT_REPOSITORY osmclient IM"
    sudo apt-get update
    sudo apt-get install -y python3-pip
    sudo -H LC_ALL=C python3 -m pip install -U pip
    sudo -H LC_ALL=C python3 -m pip install -U python-magic pyangbind verboselogs
    sudo apt-get install -y python3-osm-im python3-osmclient
    #sed 's,OSM_SOL005=[^$]*,OSM_SOL005=True,' -i ${HOME}/.bashrc
    #echo 'export OSM_HOSTNAME=localhost' >> ${HOME}/.bashrc
    #echo 'export OSM_SOL005=True' >> ${HOME}/.bashrc
    [ -z "$INSTALL_LIGHTWEIGHT" ] && export OSM_HOSTNAME=`lxc list | awk '($2=="SO-ub"){print $6}'`
    [ -z "$INSTALL_LIGHTWEIGHT" ] && export OSM_RO_HOSTNAME=`lxc list | awk '($2=="RO"){print $6}'`
    echo -e "\nOSM client installed"
    if [ -z "$INSTALL_LIGHTWEIGHT" ]; then
        echo -e "You might be interested in adding the following OSM client env variables to your .bashrc file:"
        echo "     export OSM_HOSTNAME=${OSM_HOSTNAME}"
        echo "     export OSM_RO_HOSTNAME=${OSM_RO_HOSTNAME}"
    else
        echo -e "OSM client assumes that OSM host is running in localhost (127.0.0.1)."
        echo -e "In case you want to interact with a different OSM host, you will have to configure this env variable in your .bashrc file:"
        echo "     export OSM_HOSTNAME=<OSM_host>"
    fi
    return 0
}

function install_prometheus_nodeexporter(){
    if (systemctl -q is-active node_exporter)
        then
            echo "Node Exporter is already running."
        else
            echo "Node Exporter is not active, installing..."
            if getent passwd node_exporter > /dev/null 2>&1; then
                echo "node_exporter user exists"
            else
                echo "Creating user node_exporter"
                sudo useradd --no-create-home --shell /bin/false node_exporter
            fi
            sudo wget -q https://github.com/prometheus/node_exporter/releases/download/v$PROMETHEUS_NODE_EXPORTER_TAG/node_exporter-$PROMETHEUS_NODE_EXPORTER_TAG.linux-amd64.tar.gz  -P /tmp/
            sudo tar -C /tmp -xf /tmp/node_exporter-$PROMETHEUS_NODE_EXPORTER_TAG.linux-amd64.tar.gz
            sudo cp /tmp/node_exporter-$PROMETHEUS_NODE_EXPORTER_TAG.linux-amd64/node_exporter /usr/local/bin
            sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
            sudo rm -rf node_exporter-$PROMETHEUS_NODE_EXPORTER_TAG.linux-amd64*
            sudo cp ${OSM_DEVOPS}/installers/docker/files/node_exporter.service /etc/systemd/system/node_exporter.service
            sudo systemctl daemon-reload
            sudo systemctl restart node_exporter
            sudo systemctl enable node_exporter
            echo "Node Exporter has been activated in this host."
    fi
    return 0
}

function uninstall_prometheus_nodeexporter(){
    sudo systemctl stop node_exporter
    sudo systemctl disable node_exporter
    sudo rm /etc/systemd/system/node_exporter.service
    sudo systemctl daemon-reload
    sudo userdel node_exporter
    sudo rm /usr/local/bin/node_exporter
    return 0
}

function install_docker_ce() {
    # installs and configures Docker CE
    echo "Installing Docker CE ..."
    sudo apt-get -qq update
    sudo apt-get install -y apt-transport-https ca-certificates software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get -qq update
    sudo apt-get install -y docker-ce
    echo "Adding user to group 'docker'"
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
    sleep 2
    sudo service docker restart
    echo "... restarted Docker service"
    sg docker -c "docker version" || FATAL "Docker installation failed"
    echo "... Docker CE installation done"
    return 0
}

function install_docker_compose() {
    # installs and configures docker-compose
    echo "Installing Docker Compose ..."
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "... Docker Compose installation done"
}

function install_juju() {
    echo "Installing juju"
    sudo snap install juju --classic
    [ -z "$INSTALL_NOLXD" ] && sudo dpkg-reconfigure -p medium lxd
    [[ ":$PATH": != *":/snap/bin:"* ]] && PATH="/snap/bin:${PATH}"
    echo "Finished installation of juju"
    return 0
}

function juju_createcontroller() {
    if ! juju show-controller $OSM_STACK_NAME &> /dev/null; then
        # Not found created, create the controller
        sudo usermod -a -G lxd ${USER}
        sg lxd -c "juju bootstrap --bootstrap-series=xenial localhost $OSM_STACK_NAME"
    fi
    [ $(juju controllers | awk "/^${OSM_STACK_NAME}[\*| ]/{print $1}"|wc -l) -eq 1 ] || FATAL "Juju installation failed"
}

function juju_createproxy() {
    echo -e "\nChecking required packages: iptables-persistent"
    dpkg -l iptables-persistent &>/dev/null || ! echo -e "    Not installed.\nInstalling iptables-persistent requires root privileges" || \
    sudo apt-get -yq install iptables-persistent

    if ! sudo iptables -t nat -C PREROUTING -p tcp -m tcp -d $DEFAULT_IP --dport 17070 -j DNAT --to-destination $OSM_VCA_HOST; then
        sudo iptables -t nat -A PREROUTING -p tcp -m tcp -d $DEFAULT_IP --dport 17070 -j DNAT --to-destination $OSM_VCA_HOST
        sudo netfilter-persistent save
    fi
}

function generate_docker_images() {
    echo "Pulling and generating docker images"
    _build_from=$COMMIT_ID
    [ -z "$_build_from" ] && _build_from="master"

    echo "OSM Docker images generated from $_build_from"

    BUILD_ARGS+=(--build-arg REPOSITORY="$REPOSITORY")
    BUILD_ARGS+=(--build-arg RELEASE="$RELEASE")
    BUILD_ARGS+=(--build-arg REPOSITORY_KEY="$REPOSITORY_KEY")
    BUILD_ARGS+=(--build-arg REPOSITORY_BASE="$REPOSITORY_BASE")

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q KAFKA ; then
        sg docker -c "docker pull wurstmeister/zookeeper" || FATAL "cannot get zookeeper docker image"
        sg docker -c "docker pull wurstmeister/kafka:${KAFKA_TAG}" || FATAL "cannot get kafka docker image"
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q MONGO ; then
        sg docker -c "docker pull mongo" || FATAL "cannot get mongo docker image"
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q PROMETHEUS ; then
        sg docker -c "docker pull prom/prometheus:${PROMETHEUS_TAG}" || FATAL "cannot get prometheus docker image"
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q PROMETHEUS-CADVISOR ; then
        sg docker -c "docker pull google/cadvisor:${PROMETHEUS_CADVISOR_TAG}" || FATAL "cannot get prometheus cadvisor docker image"
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q GRAFANA ; then
        sg docker -c "docker pull grafana/grafana:${GRAFANA_TAG}" || FATAL "cannot get grafana docker image"
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q NBI || echo $TO_REBUILD | grep -q KEYSTONE-DB ; then
        sg docker -c "docker pull mariadb:${KEYSTONEDB_TAG}" || FATAL "cannot get keystone-db docker image"
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q RO ; then
        sg docker -c "docker pull mysql:5" || FATAL "cannot get mysql docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/mon:${OSM_DOCKER_TAG}" || FATAL "cannot pull MON docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q MON ; then
        git -C ${LWTEMPDIR} clone https://osm.etsi.org/gerrit/osm/MON
        git -C ${LWTEMPDIR}/MON checkout ${COMMIT_ID}
        sg docker -c "docker build ${LWTEMPDIR}/MON -f ${LWTEMPDIR}/MON/docker/Dockerfile -t ${DOCKER_USER}/mon --no-cache" || FATAL "cannot build MON docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/pol:${OSM_DOCKER_TAG}" || FATAL "cannot pull POL docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q POL ; then
        git -C ${LWTEMPDIR} clone https://osm.etsi.org/gerrit/osm/POL
        git -C ${LWTEMPDIR}/POL checkout ${COMMIT_ID}
        sg docker -c "docker build ${LWTEMPDIR}/POL -f ${LWTEMPDIR}/POL/docker/Dockerfile -t ${DOCKER_USER}/pol --no-cache" || FATAL "cannot build POL docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/nbi:${OSM_DOCKER_TAG}" || FATAL "cannot pull NBI docker image"
        sg docker -c "docker pull ${DOCKER_USER}/keystone:${OSM_DOCKER_TAG}" || FATAL "cannot pull KEYSTONE docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q NBI ; then
        git -C ${LWTEMPDIR} clone https://osm.etsi.org/gerrit/osm/NBI
        git -C ${LWTEMPDIR}/NBI checkout ${COMMIT_ID}
        sg docker -c "docker build ${LWTEMPDIR}/NBI -f ${LWTEMPDIR}/NBI/Dockerfile.local -t ${DOCKER_USER}/nbi --no-cache" || FATAL "cannot build NBI docker image"
        sg docker -c "docker build ${LWTEMPDIR}/NBI/keystone -f ${LWTEMPDIR}/NBI/keystone/Dockerfile -t ${DOCKER_USER}/keystone --no-cache" || FATAL "cannot build KEYSTONE docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/ro:${OSM_DOCKER_TAG}" || FATAL "cannot pull RO docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q RO ; then
        git -C ${LWTEMPDIR} clone https://osm.etsi.org/gerrit/osm/RO
        git -C ${LWTEMPDIR}/RO checkout ${COMMIT_ID}
        sg docker -c "docker build ${LWTEMPDIR}/RO -f ${LWTEMPDIR}/RO/Dockerfile-local -t ${DOCKER_USER}/ro --no-cache" || FATAL "cannot build RO docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/lcm:${OSM_DOCKER_TAG}" || FATAL "cannot pull LCM RO docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q LCM ; then
        git -C ${LWTEMPDIR} clone https://osm.etsi.org/gerrit/osm/LCM
        git -C ${LWTEMPDIR}/LCM checkout ${COMMIT_ID}
        sg docker -c "docker build ${LWTEMPDIR}/LCM -f ${LWTEMPDIR}/LCM/Dockerfile.local -t ${DOCKER_USER}/lcm --no-cache" || FATAL "cannot build LCM docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/light-ui:${OSM_DOCKER_TAG}" || FATAL "cannot pull light-ui docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q LW-UI ; then
        git -C ${LWTEMPDIR} clone https://osm.etsi.org/gerrit/osm/LW-UI
        git -C ${LWTEMPDIR}/LW-UI checkout ${COMMIT_ID}
        sg docker -c "docker build ${LWTEMPDIR}/LW-UI -f ${LWTEMPDIR}/LW-UI/docker/Dockerfile -t ${DOCKER_USER}/light-ui --no-cache" || FATAL "cannot build LW-UI docker image"
    fi

    if [ -n "$PULL_IMAGES" ]; then
        sg docker -c "docker pull ${DOCKER_USER}/osmclient:${OSM_DOCKER_TAG}" || FATAL "cannot pull osmclient docker image"
    elif [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q LW-osmclient; then
        sg docker -c "docker build -t ${DOCKER_USER}/osmclient ${BUILD_ARGS[@]} -f $OSM_DEVOPS/docker/osmclient ."
    fi

    if [ -z "$TO_REBUILD" ] || echo $TO_REBUILD | grep -q PROMETHEUS ; then
        sg docker -c "docker pull google/cadvisor:${PROMETHEUS_CADVISOR_TAG}" || FATAL "cannot get prometheus cadvisor docker image"
    fi    

    echo "Finished generation of docker images"
}

function cmp_overwrite() {
    file1="$1"
    file2="$2"
    if ! $(cmp "${file1}" "${file2}" >/dev/null 2>&1); then
        if [ -f "${file2}" ]; then
            ask_user "The file ${file2} already exists. Overwrite (y/N)? " n && cp -b ${file1} ${file2}
        else
            cp -b ${file1} ${file2}
        fi
    fi
}

function generate_docker_env_files() {
    echo "Doing a backup of existing env files"
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/keystone-db.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/keystone.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/lcm.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/lwui.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/mon.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/nbi.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/pol.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/ro-db.env{,~}
    $WORKDIR_SUDO cp $OSM_DOCKER_WORK_DIR/ro.env{,~}

    echo "Generating docker env files"
    if [ -n "$KUBERNETES" ]; then
        #Kubernetes resources
        $WORKDIR_SUDO cp -bR ${OSM_DEVOPS}/installers/docker/osm_pods $OSM_DOCKER_WORK_DIR
    else
        # Docker-compose
        $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/docker-compose.yaml $OSM_DOCKER_WORK_DIR/docker-compose.yaml

        # Prometheus
        $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/files/prometheus.yml $OSM_DOCKER_WORK_DIR/prometheus.yml

        # Grafana & Prometheus Exporter files
        $WORKDIR_SUDO mkdir -p $OSM_DOCKER_WORK_DIR/files
        $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/files/* $OSM_DOCKER_WORK_DIR/files/
    fi

    # LCM
    if [ ! -f $OSM_DOCKER_WORK_DIR/lcm.env ]; then
        echo "OSMLCM_DATABASE_COMMONKEY=${OSM_DATABASE_COMMONKEY}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_HOST" $OSM_DOCKER_WORK_DIR/lcm.env; then
        echo "OSMLCM_VCA_HOST=${OSM_VCA_HOST}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    else
        $WORKDIR_SUDO sed -i "s|OSMLCM_VCA_HOST.*|OSMLCM_VCA_HOST=$OSM_VCA_HOST|g" $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_SECRET" $OSM_DOCKER_WORK_DIR/lcm.env; then
        echo "OSMLCM_VCA_SECRET=${OSM_VCA_SECRET}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    else
        $WORKDIR_SUDO sed -i "s|OSMLCM_VCA_SECRET.*|OSMLCM_VCA_SECRET=$OSM_VCA_SECRET|g" $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_PUBKEY" $OSM_DOCKER_WORK_DIR/lcm.env; then
        echo "OSMLCM_VCA_PUBKEY=${OSM_VCA_PUBKEY}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    else
        $WORKDIR_SUDO sed -i "s|OSMLCM_VCA_PUBKEY.*|OSMLCM_VCA_PUBKEY=${OSM_VCA_PUBKEY}|g" $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_CACERT" $OSM_DOCKER_WORK_DIR/lcm.env; then
       echo "OSMLCM_VCA_CACERT=${OSM_VCA_CACERT}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    else
       $WORKDIR_SUDO sed -i "s|OSMLCM_VCA_CACERT.*|OSMLCM_VCA_CACERT=${OSM_VCA_CACERT}|g" $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_APIPROXY" $OSM_DOCKER_WORK_DIR/lcm.env; then
        echo "OSMLCM_VCA_APIPROXY=${OSM_VCA_APIPROXY}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    else
        $WORKDIR_SUDO sed -i "s|OSMLCM_VCA_APIPROXY.*|OSMLCM_VCA_APIPROXY=${OSM_VCA_APIPROXY}|g" $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_ENABLEOSUPGRADE" $OSM_DOCKER_WORK_DIR/lcm.env; then
        echo "# OSMLCM_VCA_ENABLEOSUPGRADE=false" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    if ! grep -Fq "OSMLCM_VCA_APTMIRROR" $OSM_DOCKER_WORK_DIR/lcm.env; then
        echo "# OSMLCM_VCA_APTMIRROR=http://archive.ubuntu.com/ubuntu/" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lcm.env
    fi

    # RO
    MYSQL_ROOT_PASSWORD=$(generate_secret)
    if [ ! -f $OSM_DOCKER_WORK_DIR/ro-db.env ]; then
        echo "MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}" |$WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/ro-db.env
    fi
    if [ ! -f $OSM_DOCKER_WORK_DIR/ro.env ]; then
        echo "RO_DB_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}" |$WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/ro.env
    fi

    # Keystone
    KEYSTONE_DB_PASSWORD=$(generate_secret)
    SERVICE_PASSWORD=$(generate_secret)
    if [ ! -f $OSM_DOCKER_WORK_DIR/keystone-db.env ]; then
        echo "MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}" |$WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/keystone-db.env
    fi
    if [ ! -f $OSM_DOCKER_WORK_DIR/keystone.env ]; then
        echo "ROOT_DB_PASSWORD=${MYSQL_ROOT_PASSWORD}" |$WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/keystone.env
        echo "KEYSTONE_DB_PASSWORD=${KEYSTONE_DB_PASSWORD}" |$WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/keystone.env
        echo "SERVICE_PASSWORD=${SERVICE_PASSWORD}" |$WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/keystone.env
    fi

    # NBI
    if [ ! -f $OSM_DOCKER_WORK_DIR/nbi.env ]; then
        echo "OSMNBI_AUTHENTICATION_SERVICE_PASSWORD=${SERVICE_PASSWORD}" |$WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/nbi.env
        echo "OSMNBI_DATABASE_COMMONKEY=${OSM_DATABASE_COMMONKEY}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/nbi.env
    fi

    # MON
    if [ ! -f $OSM_DOCKER_WORK_DIR/mon.env ]; then
        echo "OSMMON_DATABASE_COMMONKEY=${OSM_DATABASE_COMMONKEY}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/mon.env
        echo "OSMMON_SQL_DATABASE_URI=mysql://root:${MYSQL_ROOT_PASSWORD}@mysql:3306/mon" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/mon.env
    fi

    if ! grep -Fq "OS_NOTIFIER_URI" $OSM_DOCKER_WORK_DIR/mon.env; then
        echo "OS_NOTIFIER_URI=http://${DEFAULT_IP}:8662" |$WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/mon.env
    else
        $WORKDIR_SUDO sed -i "s|OS_NOTIFIER_URI.*|OS_NOTIFIER_URI=http://$DEFAULT_IP:8662|g" $OSM_DOCKER_WORK_DIR/mon.env
    fi

    if ! grep -Fq "OSMMON_VCA_HOST" $OSM_DOCKER_WORK_DIR/mon.env; then
        echo "OSMMON_VCA_HOST=${OSM_VCA_HOST}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/mon.env
    else
        $WORKDIR_SUDO sed -i "s|OSMMON_VCA_HOST.*|OSMMON_VCA_HOST=$OSM_VCA_HOST|g" $OSM_DOCKER_WORK_DIR/mon.env
    fi

    if ! grep -Fq "OSMMON_VCA_SECRET" $OSM_DOCKER_WORK_DIR/mon.env; then
        echo "OSMMON_VCA_SECRET=${OSM_VCA_SECRET}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/mon.env
    else
        $WORKDIR_SUDO sed -i "s|OSMMON_VCA_SECRET.*|OSMMON_VCA_SECRET=$OSM_VCA_SECRET|g" $OSM_DOCKER_WORK_DIR/mon.env
    fi

    if ! grep -Fq "OSMMON_VCA_CACERT" $OSM_DOCKER_WORK_DIR/mon.env; then
       echo "OSMMON_VCA_CACERT=${OSM_VCA_CACERT}" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/mon.env
    else
       $WORKDIR_SUDO sed -i "s|OSMMON_VCA_CACERT.*|OSMMON_VCA_CACERT=${OSM_VCA_CACERT}|g" $OSM_DOCKER_WORK_DIR/mon.env
    fi


    # POL
    if [ ! -f $OSM_DOCKER_WORK_DIR/pol.env ]; then
        echo "OSMPOL_SQL_DATABASE_URI=mysql://root:${MYSQL_ROOT_PASSWORD}@mysql:3306/pol" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/pol.env
    fi

    # LW-UI
    if [ ! -f $OSM_DOCKER_WORK_DIR/lwui.env ]; then
        echo "OSMUI_SQL_DATABASE_URI=mysql://root:${MYSQL_ROOT_PASSWORD}@mysql:3306/lwui" | $WORKDIR_SUDO tee -a $OSM_DOCKER_WORK_DIR/lwui.env
    fi

    echo "Finished generation of docker env files"
}

function generate_osmclient_script () {
    echo "docker run -ti --network net${OSM_STACK_NAME} ${DOCKER_USER}/osmclient:${OSM_DOCKER_TAG}" | $WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/osm
    $WORKDIR_SUDO chmod +x "$OSM_DOCKER_WORK_DIR/osm"
    echo "osmclient sidecar container can be found at: $OSM_DOCKER_WORK_DIR/osm"
}

#installs kubernetes packages
function install_kube() {
    sudo apt-get update && sudo apt-get install -y apt-transport-https
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
    sudo apt-get update
    echo "Installing Kubernetes Packages ..."
    sudo apt-get install -y kubelet=1.15.0-00 kubeadm=1.15.0-00 kubectl=1.15.0-00
}

#initializes kubernetes control plane
function init_kubeadm() {
    sudo swapoff -a
    sudo kubeadm init --config $1
    sleep 5
}

function kube_config_dir() {
    [ ! -d $K8S_MANIFEST_DIR ] && FATAL "Cannot Install Kubernetes"
    mkdir -p $HOME/.kube
    sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

#deploys flannel as daemonsets
function deploy_cni_provider() {
    CNI_DIR="$(mktemp -d -q --tmpdir "flannel.XXXXXX")"
    trap 'rm -rf "${CNI_DIR}"' EXIT
    wget -q https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml -P $CNI_DIR
    kubectl apply -f $CNI_DIR
    [ $? -ne 0 ] && FATAL "Cannot Install Flannel"
}

#creates secrets from env files which will be used by containers
function kube_secrets(){
    kubectl create ns $OSM_STACK_NAME
    kubectl create secret generic lcm-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/lcm.env
    kubectl create secret generic mon-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/mon.env
    kubectl create secret generic nbi-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/nbi.env
    kubectl create secret generic ro-db-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/ro-db.env
    kubectl create secret generic ro-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/ro.env
    kubectl create secret generic keystone-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/keystone.env
    kubectl create secret generic lwui-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/lwui.env
    kubectl create secret generic pol-secret -n $OSM_STACK_NAME --from-env-file=$OSM_DOCKER_WORK_DIR/pol.env
}

#deploys osm pods and services
function deploy_osm_services() {
    K8S_MASTER=$(kubectl get nodes | awk '$3~/master/'| awk '{print $1}')
    kubectl taint node $K8S_MASTER node-role.kubernetes.io/master:NoSchedule-
    sleep 5
    kubectl apply -n $OSM_STACK_NAME -f $OSM_K8S_WORK_DIR
}

function parse_yaml() {
    osm_services="nbi lcm ro pol mon light-ui keystone"
    TAG=$1
    for osm in $osm_services; do
        $WORKDIR_SUDO sed -i "s/opensourcemano\/$osm:.*/opensourcemano\/$osm:$TAG/g" $OSM_K8S_WORK_DIR/$osm.yaml
    done
}

function namespace_vol() {
    osm_services="nbi lcm ro pol mon kafka mongo mysql"
    for osm in $osm_services; do
          $WORKDIR_SUDO  sed -i "s#path: /var/lib/osm#path: $OSM_NAMESPACE_VOL#g" $OSM_K8S_WORK_DIR/$osm.yaml
    done
}

function init_docker_swarm() {
    if [ "${DEFAULT_MTU}" != "1500" ]; then
      DOCKER_NETS=`sg docker -c "docker network list" | awk '{print $2}' | egrep -v "^ID$" | paste -d " " -s`
      DOCKER_GW_NET=`sg docker -c "docker network inspect ${DOCKER_NETS}" | grep Subnet | awk -F\" '{print $4}' | egrep "^172" | sort -u | tail -1 |  awk -F\. '{if ($2 != 255) print $1"."$2+1"."$3"."$4; else print "-1";}'`
      sg docker -c "docker network create --subnet ${DOCKER_GW_NET} --opt com.docker.network.bridge.name=docker_gwbridge --opt com.docker.network.bridge.enable_icc=false --opt com.docker.network.bridge.enable_ip_masquerade=true --opt com.docker.network.driver.mtu=${DEFAULT_MTU} docker_gwbridge"
    fi
    sg docker -c "docker swarm init --advertise-addr ${DEFAULT_IP}"
    return 0
}

function create_docker_network() {
    echo "creating network"
    sg docker -c "docker network create --driver=overlay --attachable --opt com.docker.network.driver.mtu=${DEFAULT_MTU} net${OSM_STACK_NAME}"
    echo "creating network DONE"
}

function deploy_lightweight() {

    echo "Deploying lightweight build"
    OSM_NBI_PORT=9999
    OSM_RO_PORT=9090
    OSM_KEYSTONE_PORT=5000
    OSM_UI_PORT=80
    OSM_MON_PORT=8662
    OSM_PROM_PORT=9090
    OSM_PROM_CADVISOR_PORT=8080
    OSM_PROM_HOSTPORT=9091
    OSM_GRAFANA_PORT=3000
    [ -n "$INSTALL_ELK" ] && OSM_ELK_PORT=5601
    #[ -n "$INSTALL_PERFMON" ] && OSM_PM_PORT=3000

    if [ -n "$NO_HOST_PORTS" ]; then
        OSM_PORTS+=(OSM_NBI_PORTS=$OSM_NBI_PORT)
        OSM_PORTS+=(OSM_RO_PORTS=$OSM_RO_PORT)
        OSM_PORTS+=(OSM_KEYSTONE_PORTS=$OSM_KEYSTONE_PORT)
        OSM_PORTS+=(OSM_UI_PORTS=$OSM_UI_PORT)
        OSM_PORTS+=(OSM_MON_PORTS=$OSM_MON_PORT)
        OSM_PORTS+=(OSM_PROM_PORTS=$OSM_PROM_PORT)
        OSM_PORTS+=(OSM_PROM_CADVISOR_PORTS=$OSM_PROM_CADVISOR_PORT)
        OSM_PORTS+=(OSM_GRAFANA_PORTS=$OSM_GRAFANA_PORT)
        #[ -n "$INSTALL_PERFMON" ] && OSM_PORTS+=(OSM_PM_PORTS=$OSM_PM_PORT)
        [ -n "$INSTALL_ELK" ] && OSM_PORTS+=(OSM_ELK_PORTS=$OSM_ELK_PORT)
    else
        OSM_PORTS+=(OSM_NBI_PORTS=$OSM_NBI_PORT:$OSM_NBI_PORT)
        OSM_PORTS+=(OSM_RO_PORTS=$OSM_RO_PORT:$OSM_RO_PORT)
        OSM_PORTS+=(OSM_KEYSTONE_PORTS=$OSM_KEYSTONE_PORT:$OSM_KEYSTONE_PORT)
        OSM_PORTS+=(OSM_UI_PORTS=$OSM_UI_PORT:$OSM_UI_PORT)
        OSM_PORTS+=(OSM_MON_PORTS=$OSM_MON_PORT:$OSM_MON_PORT)
        OSM_PORTS+=(OSM_PROM_PORTS=$OSM_PROM_HOSTPORT:$OSM_PROM_PORT)
        OSM_PORTS+=(OSM_PROM_CADVISOR_PORTS=$OSM_PROM_CADVISOR_PORT:$OSM_PROM_CADVISOR_PORT)
        OSM_PORTS+=(OSM_GRAFANA_PORTS=$OSM_GRAFANA_PORT:$OSM_GRAFANA_PORT)
        #[ -n "$INSTALL_PERFMON" ] && OSM_PORTS+=(OSM_PM_PORTS=$OSM_PM_PORT:$OSM_PM_PORT)
        [ -n "$INSTALL_ELK" ] && OSM_PORTS+=(OSM_ELK_PORTS=$OSM_ELK_PORT:$OSM_ELK_PORT)
    fi
    echo "export ${OSM_PORTS[@]}" | $WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export OSM_NETWORK=net${OSM_STACK_NAME}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export TAG=${OSM_DOCKER_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export DOCKER_USER=${DOCKER_USER}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export KAFKA_TAG=${KAFKA_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export PROMETHEUS_TAG=${PROMETHEUS_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export KEYSTONEDB_TAG=${KEYSTONEDB_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export PROMETHEUS_CADVISOR_TAG=${PROMETHEUS_CADVISOR_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export GRAFANA_TAG=${GRAFANA_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh

    pushd $OSM_DOCKER_WORK_DIR
    sg docker -c ". ./osm_ports.sh; docker stack deploy -c $OSM_DOCKER_WORK_DIR/docker-compose.yaml $OSM_STACK_NAME"
    popd

    echo "Finished deployment of lightweight build"
}

function deploy_elk() {
    echo "Pulling docker images for ELK"
    sg docker -c "docker pull docker.elastic.co/elasticsearch/elasticsearch-oss:${ELASTIC_VERSION}" || FATAL "cannot get elasticsearch docker image"
    sg docker -c "docker pull docker.elastic.co/beats/metricbeat:${ELASTIC_VERSION}" || FATAL "cannot get metricbeat docker image"
    sg docker -c "docker pull docker.elastic.co/beats/filebeat:${ELASTIC_VERSION}" || FATAL "cannot get filebeat docker image"
    sg docker -c "docker pull docker.elastic.co/kibana/kibana-oss:${ELASTIC_VERSION}" || FATAL "cannot get kibana docker image"
    sg docker -c "docker pull bobrik/curator:${ELASTIC_CURATOR_VERSION}" || FATAL "cannot get curator docker image"
    echo "Finished pulling elk docker images"
    $WORKDIR_SUDO mkdir -p "$OSM_DOCKER_WORK_DIR/osm_elk"
    $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/osm_elk/* $OSM_DOCKER_WORK_DIR/osm_elk
    remove_stack osm_elk
    echo "Deploying ELK stack"
    sg docker -c "OSM_NETWORK=net${OSM_STACK_NAME} docker stack deploy -c $OSM_DOCKER_WORK_DIR/osm_elk/docker-compose.yml osm_elk"
    echo "Waiting for ELK stack to be up and running"
    time=0
    step=5
    timelength=40
    elk_is_up=1
    while [ $time -le $timelength ]; do
        if [[ $(curl -f -XGET http://127.0.0.1:5601/status -I 2>/dev/null | grep "HTTP/1.1 200 OK" | wc -l ) -eq 1 ]]; then
            elk_is_up=0
            break
        fi
        sleep $step
        time=$((time+step))
    done
    if [ $elk_is_up -eq 0 ]; then
        echo "ELK is up and running. Trying to create index pattern..."
        #Create index pattern
        curl -f -XPOST -H "Content-Type: application/json" -H "kbn-xsrf: anything" \
          "http://127.0.0.1:5601/api/saved_objects/index-pattern/filebeat-*" \
          -d"{\"attributes\":{\"title\":\"filebeat-*\",\"timeFieldName\":\"@timestamp\"}}" 2>/dev/null
        #Make it the default index
        curl -f -XPOST -H "Content-Type: application/json" -H "kbn-xsrf: anything" \
          "http://127.0.0.1:5601/api/kibana/settings/defaultIndex" \
          -d"{\"value\":\"filebeat-*\"}" 2>/dev/null
    else
        echo "Cannot connect to Kibana to create index pattern."
        echo "Once Kibana is running, you can use the following instructions to create index pattern:"
        echo 'curl -f -XPOST -H "Content-Type: application/json" -H "kbn-xsrf: anything" \
          "http://127.0.0.1:5601/api/saved_objects/index-pattern/filebeat-*" \
          -d"{\"attributes\":{\"title\":\"filebeat-*\",\"timeFieldName\":\"@timestamp\"}}"'
        echo 'curl -XPOST -H "Content-Type: application/json" -H "kbn-xsrf: anything" \
          "http://127.0.0.1:5601/api/kibana/settings/defaultIndex" \
          -d"{\"value\":\"filebeat-*\"}"'
    fi
    echo "Finished deployment of ELK stack"
    return 0
}

function install_lightweight() {
    [ "${OSM_STACK_NAME}" == "osm" ] || OSM_DOCKER_WORK_DIR="$OSM_WORK_DIR/stack/$OSM_STACK_NAME"
    [ -n "$KUBERNETES" ] && OSM_K8S_WORK_DIR="$OSM_DOCKER_WORK_DIR/osm_pods" && OSM_NAMESPACE_VOL="${OSM_HOST_VOL}/${OSM_STACK_NAME}"
    [ ! -d "$OSM_DOCKER_WORK_DIR" ] && $WORKDIR_SUDO mkdir -p $OSM_DOCKER_WORK_DIR
    [ -n "$KUBERNETES" ] && $WORKDIR_SUDO cp -b $OSM_DEVOPS/installers/docker/cluster-config.yaml $OSM_DOCKER_WORK_DIR/cluster-config.yaml

    track checkingroot
    [ "$USER" == "root" ] && FATAL "You are running the installer as root. The installer is prepared to be executed as a normal user with sudo privileges."
    track noroot

    if [ -n "$KUBERNETES" ]; then
        [ -z "$ASSUME_YES" ] && ! ask_user "The installation will do the following
        1. Install and configure LXD
        2. Install juju
        3. Install docker CE
        4. Disable swap space
        5. Install and initialize Kubernetes
        as pre-requirements.
        Do you want to proceed (Y/n)? " y && echo "Cancelled!" && exit 1

    else
        [ -z "$ASSUME_YES" ] && ! ask_user "The installation will configure LXD, install juju, install docker CE and init a docker swarm, as pre-requirements. Do you want to proceed (Y/n)? " y && echo "Cancelled!" && exit 1
    fi
    track proceed

    echo "Installing lightweight build of OSM"
    LWTEMPDIR="$(mktemp -d -q --tmpdir "installosmlight.XXXXXX")"
    trap 'rm -rf "${LWTEMPDIR}"' EXIT
    DEFAULT_IF=`route -n |awk '$1~/^0.0.0.0/ {print $8}'`
    [ -z "$DEFAULT_IF" ] && FATAL "Not possible to determine the interface with the default route 0.0.0.0"
    DEFAULT_IP=`ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}'`
    [ -z "$DEFAULT_IP" ] && FATAL "Not possible to determine the IP address of the interface with the default route"
    DEFAULT_MTU=$(ip addr show ${DEFAULT_IF} | perl -ne 'if (/mtu\s(\d+)/) {print $1;}')

    # if no host is passed in, we need to install lxd/juju, unless explicilty asked not to
    if [ -z "$OSM_VCA_HOST" ] && [ -z "$INSTALL_NOLXD" ]; then
        need_packages_lw="lxd snapd"
        echo -e "Checking required packages: $need_packages_lw"
        dpkg -l $need_packages_lw &>/dev/null \
          || ! echo -e "One or several required packages are not installed. Updating apt cache requires root privileges." \
          || sudo apt-get update \
          || FATAL "failed to run apt-get update"
        dpkg -l $need_packages_lw &>/dev/null \
          || ! echo -e "Installing $need_packages_lw requires root privileges." \
          || sudo apt-get install -y $need_packages_lw \
          || FATAL "failed to install $need_packages_lw"
    fi
    track prereqok

    [ -z "$INSTALL_NOJUJU" ] && install_juju
    track juju_install

    if [ -z "$OSM_VCA_HOST" ]; then
        juju_createcontroller
        OSM_VCA_HOST=`sg lxd -c "juju show-controller $OSM_STACK_NAME"|grep api-endpoints|awk -F\' '{print $2}'|awk -F\: '{print $1}'`
        [ -z "$OSM_VCA_HOST" ] && FATAL "Cannot obtain juju controller IP address"
    fi
    track juju_controller

    if [ -z "$OSM_VCA_SECRET" ]; then
        OSM_VCA_SECRET=$(parse_juju_password $OSM_STACK_NAME)
        [ -z "$OSM_VCA_SECRET" ] && FATAL "Cannot obtain juju secret"
    fi
    if [ -z "$OSM_VCA_PUBKEY" ]; then
        OSM_VCA_PUBKEY=$(cat $HOME/.local/share/juju/ssh/juju_id_rsa.pub)
        [ -z "$OSM_VCA_PUBKEY" ] && FATAL "Cannot obtain juju public key"
    fi
    if [ -z "$OSM_VCA_CACERT" ]; then
	OSM_VCA_CACERT=$(juju controllers --format json | jq -r '.controllers["osm"]["ca-cert"]' | base64 | tr -d \\n)
       [ -z "$OSM_VCA_CACERT" ] && FATAL "Cannot obtain juju CA certificate"
    fi
    if [ -z "$OSM_VCA_APIPROXY" ]; then
        OSM_VCA_APIPROXY=$DEFAULT_IP
        [ -z "$OSM_VCA_APIPROXY" ] && FATAL "Cannot obtain juju api proxy"
    fi
    juju_createproxy
    track juju

    if [ -z "$OSM_DATABASE_COMMONKEY" ]; then
        OSM_DATABASE_COMMONKEY=$(generate_secret)
        [ -z "OSM_DATABASE_COMMONKEY" ] && FATAL "Cannot generate common db secret"
    fi

    [ -n "$INSTALL_NODOCKER" ] || install_docker_ce
    track docker_ce

    #Installs Kubernetes and deploys osm services
    if [ -n "$KUBERNETES" ]; then
        install_kube
        track install_k8s
        init_kubeadm $OSM_DOCKER_WORK_DIR/cluster-config.yaml
        kube_config_dir
        track init_k8s
    else
        #install_docker_compose
        [ -n "$INSTALL_NODOCKER" ] || init_docker_swarm
        track docker_swarm
    fi

    [ -z "$DOCKER_NOBUILD" ] && generate_docker_images
    track docker_build

    generate_docker_env_files

    if [ -n "$KUBERNETES" ]; then
        if [ -n "$K8S_MONITOR" ]; then
            # uninstall OSM MONITORING
            uninstall_k8s_monitoring
            track uninstall_k8s_monitoring
        fi
        #remove old namespace
        remove_k8s_namespace $OSM_STACK_NAME
        deploy_cni_provider
        kube_secrets
        [ ! $OSM_DOCKER_TAG == "7" ] && parse_yaml $OSM_DOCKER_TAG
        namespace_vol
        deploy_osm_services
        track deploy_osm_services_k8s
        if [ -n "$K8S_MONITOR" ]; then
            # install OSM MONITORING
            install_k8s_monitoring
            track install_k8s_monitoring
        fi
    else
        # remove old stack
        remove_stack $OSM_STACK_NAME
        create_docker_network
        deploy_lightweight
        generate_osmclient_script
        track docker_deploy
        install_prometheus_nodeexporter
        track nodeexporter
        [ -n "$INSTALL_VIMEMU" ] && install_vimemu && track vimemu
        [ -n "$INSTALL_ELK" ] && deploy_elk && track elk
    fi

    [ -z "$INSTALL_NOHOSTCLIENT" ] && install_osmclient
    track osmclient

    wget -q -O- https://osm-download.etsi.org/ftp/osm-7.0-seven/README2.txt &> /dev/null
    track end
    return 0
}

function install_vimemu() {
    echo "\nInstalling vim-emu"
    EMUTEMPDIR="$(mktemp -d -q --tmpdir "installosmvimemu.XXXXXX")"
    trap 'rm -rf "${EMUTEMPDIR}"' EXIT
    # clone vim-emu repository (attention: branch is currently master only)
    echo "Cloning vim-emu repository ..."
    git clone https://osm.etsi.org/gerrit/osm/vim-emu.git $EMUTEMPDIR
    # build vim-emu docker
    echo "Building vim-emu Docker container..."

    sg docker -c "docker build -t vim-emu-img -f $EMUTEMPDIR/Dockerfile --no-cache $EMUTEMPDIR/" || FATAL "cannot build vim-emu-img docker image"
    # start vim-emu container as daemon
    echo "Starting vim-emu Docker container 'vim-emu' ..."
    if [ -n "$INSTALL_LIGHTWEIGHT" ]; then
        # in lightweight mode, the emulator needs to be attached to netOSM
        sg docker -c "docker run --name vim-emu -t -d --restart always --privileged --pid='host' --network=net${OSM_STACK_NAME} -v /var/run/docker.sock:/var/run/docker.sock vim-emu-img python examples/osm_default_daemon_topology_2_pop.py"
    else
        # classic build mode
        sg docker -c "docker run --name vim-emu -t -d --restart always --privileged --pid='host' -v /var/run/docker.sock:/var/run/docker.sock vim-emu-img python examples/osm_default_daemon_topology_2_pop.py"
    fi
    echo "Waiting for 'vim-emu' container to start ..."
    sleep 5
    export VIMEMU_HOSTNAME=$(sg docker -c "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vim-emu")
    echo "vim-emu running at ${VIMEMU_HOSTNAME} ..."
    # print vim-emu connection info
    echo -e "\nYou might be interested in adding the following vim-emu env variables to your .bashrc file:"
    echo "     export VIMEMU_HOSTNAME=${VIMEMU_HOSTNAME}"
    echo -e "To add the emulated VIM to OSM you should do:"
    echo "     osm vim-create --name emu-vim1 --user username --password password --auth_url http://${VIMEMU_HOSTNAME}:6001/v2.0 --tenant tenantName --account_type openstack"
}

function install_k8s_monitoring() {
    # install OSM monitoring
    $WORKDIR_SUDO chmod +x $OSM_DEVOPS/installers/k8s/*.sh
    $WORKDIR_SUDO $OSM_DEVOPS/installers/k8s/install_osm_k8s_monitoring.sh
}

function uninstall_k8s_monitoring() {
    # uninstall OSM monitoring
    $WORKDIR_SUDO $OSM_DEVOPS/installers/k8s/uninstall_osm_k8s_monitoring.sh
}

function dump_vars(){
    echo "DEVELOP=$DEVELOP"
    echo "INSTALL_FROM_SOURCE=$INSTALL_FROM_SOURCE"
    echo "UNINSTALL=$UNINSTALL"
    echo "UPDATE=$UPDATE"
    echo "RECONFIGURE=$RECONFIGURE"
    echo "TEST_INSTALLER=$TEST_INSTALLER"
    echo "INSTALL_VIMEMU=$INSTALL_VIMEMU"
    echo "INSTALL_LXD=$INSTALL_LXD"
    echo "INSTALL_LIGHTWEIGHT=$INSTALL_LIGHTWEIGHT"
    echo "INSTALL_ONLY=$INSTALL_ONLY"
    echo "INSTALL_ELK=$INSTALL_ELK"
    #echo "INSTALL_PERFMON=$INSTALL_PERFMON"
    echo "TO_REBUILD=$TO_REBUILD"
    echo "INSTALL_NOLXD=$INSTALL_NOLXD"
    echo "INSTALL_NODOCKER=$INSTALL_NODOCKER"
    echo "INSTALL_NOJUJU=$INSTALL_NOJUJU"
    echo "RELEASE=$RELEASE"
    echo "REPOSITORY=$REPOSITORY"
    echo "REPOSITORY_BASE=$REPOSITORY_BASE"
    echo "REPOSITORY_KEY=$REPOSITORY_KEY"
    echo "OSM_DEVOPS=$OSM_DEVOPS"
    echo "OSM_VCA_HOST=$OSM_VCA_HOST"
    echo "OSM_VCA_SECRET=$OSM_VCA_SECRET"
    echo "OSM_VCA_PUBKEY=$OSM_VCA_PUBKEY"
    echo "NO_HOST_PORTS=$NO_HOST_PORTS"
    echo "DOCKER_NOBUILD=$DOCKER_NOBUILD"
    echo "WORKDIR_SUDO=$WORKDIR_SUDO"
    echo "OSM_WORK_DIR=$OSM_STACK_NAME"
    echo "OSM_DOCKER_TAG=$OSM_DOCKER_TAG"
    echo "DOCKER_USER=$DOCKER_USER"
    echo "OSM_STACK_NAME=$OSM_STACK_NAME"
    echo "PULL_IMAGES=$PULL_IMAGES"
    echo "KUBERNETES=$KUBERNETES"
    echo "SHOWOPTS=$SHOWOPTS"
    echo "Install from specific refspec (-b): $COMMIT_ID"
}

function track(){
    ctime=`date +%s`
    duration=$((ctime - SESSION_ID))
    url="http://www.woopra.com/track/ce?project=osm.etsi.org&cookie=${SESSION_ID}"
    #url="${url}&ce_campaign_name=${CAMPAIGN_NAME}"
    event_name="bin"
    [ -z "$INSTALL_LIGHTWEIGHT" ] && [ -n "$INSTALL_FROM_SOURCE" ] && event_name="binsrc"
    [ -z "$INSTALL_LIGHTWEIGHT" ] && [ -n "$INSTALL_FROM_LXDIMAGES" ] && event_name="lxd"
    [ -n "$INSTALL_LIGHTWEIGHT" ] && event_name="lw"
    event_name="${event_name}_$1"
    url="${url}&event=${event_name}&ce_duration=${duration}"
    wget -q -O /dev/null $url
}

UNINSTALL=""
DEVELOP=""
UPDATE=""
RECONFIGURE=""
TEST_INSTALLER=""
INSTALL_LXD=""
SHOWOPTS=""
COMMIT_ID=""
ASSUME_YES=""
INSTALL_FROM_SOURCE=""
RELEASE="ReleaseSEVEN"
REPOSITORY="stable"
INSTALL_VIMEMU=""
LXD_REPOSITORY_BASE="https://osm-download.etsi.org/repository/osm/lxd"
LXD_REPOSITORY_PATH=""
INSTALL_LIGHTWEIGHT="y"
INSTALL_ONLY=""
INSTALL_ELK=""
TO_REBUILD=""
INSTALL_NOLXD=""
INSTALL_NODOCKER=""
INSTALL_NOJUJU=""
KUBERNETES=""
K8S_MONITOR=""
INSTALL_NOHOSTCLIENT=""
SESSION_ID=`date +%s`
OSM_DEVOPS=
OSM_VCA_HOST=
OSM_VCA_SECRET=
OSM_VCA_PUBKEY=
OSM_STACK_NAME=osm
NO_HOST_PORTS=""
DOCKER_NOBUILD=""
REPOSITORY_KEY="OSM%20ETSI%20Release%20Key.gpg"
REPOSITORY_BASE="https://osm-download.etsi.org/repository/osm/debian"
WORKDIR_SUDO=sudo
OSM_WORK_DIR="/etc/osm"
OSM_DOCKER_WORK_DIR="/etc/osm/docker"
OSM_K8S_WORK_DIR="${OSM_DOCKER_WORK_DIR}/osm_pods"
OSM_HOST_VOL="/var/lib/osm"
OSM_NAMESPACE_VOL="${OSM_HOST_VOL}/${OSM_STACK_NAME}"
OSM_DOCKER_TAG=latest
DOCKER_USER=opensourcemano
PULL_IMAGES="y"
KAFKA_TAG=2.11-1.0.2
PROMETHEUS_TAG=v2.4.3
GRAFANA_TAG=latest
PROMETHEUS_NODE_EXPORTER_TAG=0.18.1
PROMETHEUS_CADVISOR_TAG=latest
KEYSTONEDB_TAG=10
OSM_DATABASE_COMMONKEY=
ELASTIC_VERSION=6.4.2
ELASTIC_CURATOR_VERSION=5.5.4
POD_NETWORK_CIDR=10.244.0.0/16
K8S_MANIFEST_DIR="/etc/kubernetes/manifests"
RE_CHECK='^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'

while getopts ":b:r:c:k:u:R:D:o:m:H:S:s:w:t:U:P:A:-: hy" o; do
    case "${o}" in
        b)
            COMMIT_ID=${OPTARG}
            PULL_IMAGES=""
            ;;
        r)
            REPOSITORY="${OPTARG}"
            REPO_ARGS+=(-r "$REPOSITORY")
            ;;
        c)
            [ "${OPTARG}" == "swarm" ] && continue
            [ "${OPTARG}" == "k8s" ] && KUBERNETES="y" && continue
            echo -e "Invalid argument for -i : ' $OPTARG'\n" >&2
            usage && exit 1
            ;;
        k)
            REPOSITORY_KEY="${OPTARG}"
            REPO_ARGS+=(-k "$REPOSITORY_KEY")
            ;;
        u)
            REPOSITORY_BASE="${OPTARG}"
            REPO_ARGS+=(-u "$REPOSITORY_BASE")
            ;;
        R)
            RELEASE="${OPTARG}"
            REPO_ARGS+=(-R "$RELEASE")
            ;;
        D)
            OSM_DEVOPS="${OPTARG}"
            ;;
        o)
            INSTALL_ONLY="y"
            [ "${OPTARG}" == "vimemu" ] && INSTALL_VIMEMU="y" && continue
            [ "${OPTARG}" == "elk_stack" ] && INSTALL_ELK="y" && continue
            ;;
        m)
            [ "${OPTARG}" == "LW-UI" ] && TO_REBUILD="$TO_REBUILD LW-UI" && continue
            [ "${OPTARG}" == "NBI" ] && TO_REBUILD="$TO_REBUILD NBI" && continue
            [ "${OPTARG}" == "LCM" ] && TO_REBUILD="$TO_REBUILD LCM" && continue
            [ "${OPTARG}" == "RO" ] && TO_REBUILD="$TO_REBUILD RO" && continue
            [ "${OPTARG}" == "MON" ] && TO_REBUILD="$TO_REBUILD MON" && continue
            [ "${OPTARG}" == "POL" ] && TO_REBUILD="$TO_REBUILD POL" && continue
            [ "${OPTARG}" == "KAFKA" ] && TO_REBUILD="$TO_REBUILD KAFKA" && continue
            [ "${OPTARG}" == "MONGO" ] && TO_REBUILD="$TO_REBUILD MONGO" && continue
            [ "${OPTARG}" == "PROMETHEUS" ] && TO_REBUILD="$TO_REBUILD PROMETHEUS" && continue
            [ "${OPTARG}" == "PROMETHEUS-CADVISOR" ] && TO_REBUILD="$TO_REBUILD PROMETHEUS-CADVISOR" && continue
            [ "${OPTARG}" == "KEYSTONE-DB" ] && TO_REBUILD="$TO_REBUILD KEYSTONE-DB" && continue
            [ "${OPTARG}" == "GRAFANA" ] && TO_REBUILD="$TO_REBUILD GRAFANA" && continue
            [ "${OPTARG}" == "NONE" ] && TO_REBUILD="$TO_REBUILD NONE" && continue
            ;;
        H)
            OSM_VCA_HOST="${OPTARG}"
            ;;
        S)
            OSM_VCA_SECRET="${OPTARG}"
            ;;
        s)
            OSM_STACK_NAME="${OPTARG}" && [ -n "$KUBERNETES" ] && [[ ! "${OPTARG}" =~ $RE_CHECK ]] && echo "Namespace $OPTARG is invalid. Regex used for validation is $RE_CHECK" && exit 0
            ;;
        w)
            # when specifying workdir, do not use sudo for access
            WORKDIR_SUDO=
            OSM_WORK_DIR="${OPTARG}"
            ;;
        t)
            OSM_DOCKER_TAG="${OPTARG}"
            ;;
        U)
            DOCKER_USER="${OPTARG}"
            ;;
        P)
            OSM_VCA_PUBKEY=$(cat ${OPTARG})
            ;;
        A)
            OSM_VCA_APIPROXY="${OPTARG}"
            ;;
        -)
            [ "${OPTARG}" == "help" ] && usage && exit 0
            [ "${OPTARG}" == "source" ] && INSTALL_FROM_SOURCE="y" && PULL_IMAGES="" && continue
            [ "${OPTARG}" == "develop" ] && DEVELOP="y" && continue
            [ "${OPTARG}" == "uninstall" ] && UNINSTALL="y" && continue
            [ "${OPTARG}" == "update" ] && UPDATE="y" && continue
            [ "${OPTARG}" == "reconfigure" ] && RECONFIGURE="y" && continue
            [ "${OPTARG}" == "test" ] && TEST_INSTALLER="y" && continue
            [ "${OPTARG}" == "lxdinstall" ] && INSTALL_LXD="y" && continue
            [ "${OPTARG}" == "nolxd" ] && INSTALL_NOLXD="y" && continue
            [ "${OPTARG}" == "nodocker" ] && INSTALL_NODOCKER="y" && continue
            [ "${OPTARG}" == "lightweight" ] && INSTALL_LIGHTWEIGHT="y" && continue
            [ "${OPTARG}" == "vimemu" ] && INSTALL_VIMEMU="y" && continue
            [ "${OPTARG}" == "elk_stack" ] && INSTALL_ELK="y" && continue
            [ "${OPTARG}" == "showopts" ] && SHOWOPTS="y" && continue
            [ "${OPTARG}" == "nohostports" ] && NO_HOST_PORTS="y" && continue
            [ "${OPTARG}" == "nojuju" ] && INSTALL_NOJUJU="y" && continue
            [ "${OPTARG}" == "nodockerbuild" ] && DOCKER_NOBUILD="y" && continue
            [ "${OPTARG}" == "nohostclient" ] && INSTALL_NOHOSTCLIENT="y" && continue
            [ "${OPTARG}" == "pullimages" ] && continue
            [ "${OPTARG}" == "k8s_monitor" ] && K8S_MONITOR="y" && continue
            echo -e "Invalid option: '--$OPTARG'\n" >&2
            usage && exit 1
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
        y)
            ASSUME_YES="y"
            ;;
        *)
            usage && exit 1
            ;;
    esac
done

[ -n "$TO_REBUILD" ] && [ "$TO_REBUILD" != " NONE" ] && echo $TO_REBUILD | grep -q NONE && FATAL "Incompatible option: -m NONE cannot be used with other -m options"

if [ -n "$SHOWOPTS" ]; then
    dump_vars
    exit 0
fi

# if develop, we force master
[ -z "$COMMIT_ID" ] && [ -n "$DEVELOP" ] && COMMIT_ID="master"

need_packages="git jq wget curl tar"
echo -e "Checking required packages: $need_packages"
dpkg -l $need_packages &>/dev/null \
  || ! echo -e "One or several required packages are not installed. Updating apt cache requires root privileges." \
  || sudo apt-get update \
  || FATAL "failed to run apt-get update"
dpkg -l $need_packages &>/dev/null \
  || ! echo -e "Installing $need_packages requires root privileges." \
  || sudo apt-get install -y $need_packages \
  || FATAL "failed to install $need_packages"

if [ -z "$OSM_DEVOPS" ]; then
    if [ -n "$TEST_INSTALLER" ]; then
        echo -e "\nUsing local devops repo for OSM installation"
        OSM_DEVOPS="$(dirname $(realpath $(dirname $0)))"
    else
        echo -e "\nCreating temporary dir for OSM installation"
        OSM_DEVOPS="$(mktemp -d -q --tmpdir "installosm.XXXXXX")"
        trap 'rm -rf "$OSM_DEVOPS"' EXIT

        git clone https://osm.etsi.org/gerrit/osm/devops.git $OSM_DEVOPS

        if [ -z "$COMMIT_ID" ]; then
            echo -e "\nGuessing the current stable release"
            LATEST_STABLE_DEVOPS=`git -C $OSM_DEVOPS tag -l v[0-9].* | sort -V | tail -n1`
            [ -z "$LATEST_STABLE_DEVOPS" ] && echo "Could not find the current latest stable release" && exit 0

            echo "Latest tag in devops repo: $LATEST_STABLE_DEVOPS"
            COMMIT_ID="tags/$LATEST_STABLE_DEVOPS"
        else
            echo -e "\nDEVOPS Using commit $COMMIT_ID"
        fi
        git -C $OSM_DEVOPS checkout $COMMIT_ID
    fi
fi

. $OSM_DEVOPS/common/all_funcs

[ -n "$INSTALL_LIGHTWEIGHT" ] && [ -n "$UNINSTALL" ] && uninstall_lightweight && echo -e "\nDONE" && exit 0
[ -n "$INSTALL_ONLY" ] && [ -n "$INSTALL_ELK" ] && deploy_elk
#[ -n "$INSTALL_ONLY" ] && [ -n "$INSTALL_PERFMON" ] && deploy_perfmon
[ -n "$INSTALL_ONLY" ] && [ -n "$INSTALL_VIMEMU" ] && install_vimemu
[ -n "$INSTALL_ONLY" ] && echo -e "\nDONE" && exit 0

#Installation starts here
wget -q -O- https://osm-download.etsi.org/ftp/osm-7.0-seven/README.txt &> /dev/null
track start

[ -n "$INSTALL_LIGHTWEIGHT" ] && install_lightweight && echo -e "\nDONE" && exit 0
echo -e "\nInstalling OSM from refspec: $COMMIT_ID"
if [ -n "$INSTALL_FROM_SOURCE" ] && [ -z "$ASSUME_YES" ]; then
    ! ask_user "The installation will take about 75-90 minutes. Continue (Y/n)? " y && echo "Cancelled!" && exit 1
fi

echo -e "Checking required packages: lxd"
lxd --version &>/dev/null || FATAL "lxd not present, exiting."
[ -n "$INSTALL_LXD" ] && echo -e "\nInstalling and configuring lxd" && install_lxd

# use local devops for containers
export OSM_USE_LOCAL_DEVOPS=true

#Install osmclient

#Install vim-emu (optional)
[ -n "$INSTALL_VIMEMU" ] && install_docker_ce && install_vimemu

wget -q -O- https://osm-download.etsi.org/ftp/osm-7.0-seven/README2.txt &> /dev/null
track end
echo -e "\nDONE"
