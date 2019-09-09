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
    echo -e "     -s <stack name> user defined stack name, default is osm"
    echo -e "     -H <VCA host>   use specific juju host controller IP"
    echo -e "     -S <VCA secret> use VCA/juju secret key"
    echo -e "     -P <VCA pubkey> use VCA/juju public key file"
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
#    echo -e "     --reconfigure:  reconfigure the modules (DO NOT change NAT rules)"
    echo -e "     --nat:          (only for Rel THREE with --soui) install only NAT rules"
    echo -e "     --noconfigure:  (only for Rel THREE with --soui) DO NOT install osmclient, DO NOT install NAT rules, DO NOT configure modules"
#    echo -e "     --update:       update to the latest stable release or to the latest commit if using a specific branch"
    echo -e "     --showopts:     print chosen options and exit (only for debugging)"
    echo -e "     -y:             do not prompt for confirmation, assumes yes"
    echo -e "     -h / --help:    print this help"
}

#Uninstall OSM: remove containers
function uninstall(){
    echo -e "\nUninstalling OSM"
    if [ $RC_CLONE ] || [ -n "$TEST_INSTALLER" ]; then
        $OSM_DEVOPS/jenkins/host/clean_container RO
        $OSM_DEVOPS/jenkins/host/clean_container VCA
        $OSM_DEVOPS/jenkins/host/clean_container MON
        $OSM_DEVOPS/jenkins/host/clean_container SO
        #$OSM_DEVOPS/jenkins/host/clean_container UI
    else
        lxc stop RO && lxc delete RO
        lxc stop VCA && lxc delete VCA
        lxc stop MON && lxc delete MON
        lxc stop SO-ub && lxc delete SO-ub
    fi
    echo -e "\nDeleting imported lxd images if they exist"
    lxc image show osm-ro &>/dev/null && lxc image delete osm-ro
    lxc image show osm-vca &>/dev/null && lxc image delete osm-vca
    lxc image show osm-soui &>/dev/null && lxc image delete osm-soui
    return 0
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
    stack=$1
    volumes="mongo_db mon_db osm_packages ro_db"
    for volume in $volumes; do
        sg docker -c "docker volume rm ${stack}_${volume}"
    done
}

function remove_network() {
    stack=$1
    sg docker -c "docker network rm net${stack}"
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

#Uninstall lightweight OSM: remove dockers
function uninstall_lightweight() {
    if [ -n "$INSTALL_ONLY" ]; then
        if [ -n "$INSTALL_ELK" ]; then
            echo -e "\nUninstalling OSM ELK stack"
            remove_stack osm_elk
            $WORKDIR_SUDO rm -rf $OSM_DOCKER_WORK_DIR/osm_elk
        fi
        if [ -n "$INSTALL_PERFMON" ]; then
            echo -e "\nUninstalling OSM Performance Monitoring stack"
            remove_stack osm_metrics
            $WORKDIR_SUDO rm -rf $OSM_DOCKER_WORK_DIR/osm_metrics
        fi
    else
        echo -e "\nUninstalling OSM"
        remove_stack $OSM_STACK_NAME
        remove_stack osm_elk
        remove_stack osm_metrics
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
        remove_volumes $OSM_STACK_NAME
        remove_network $OSM_STACK_NAME
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
    sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install iptables-persistent
    echo -e "\nConfiguring NAT rules"
    echo -e "   Required root privileges"
    sudo $OSM_DEVOPS/installers/nat_osm
}

function FATAL(){
    echo "FATAL error: Cannot install OSM due to \"$1\""
    exit 1
}

#Update RO, SO and UI:
function update(){
    echo -e "\nUpdating components"

    echo -e "     Updating RO"
    CONTAINER="RO"
    MDG="RO"
    INSTALL_FOLDER="/opt/openmano"
    echo -e "     Fetching the repo"
    lxc exec $CONTAINER -- git -C $INSTALL_FOLDER fetch --all
    BRANCH=""
    BRANCH=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER status -sb | head -n1 | sed -n 's/^## \(.*\).*/\1/p'|awk '{print $1}' |sed 's/\(.*\)\.\.\..*/\1/'`
    [ -z "$BRANCH" ] && FATAL "Could not find the current branch in use in the '$MDG'"
    CURRENT=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER status |head -n1`
    CURRENT_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-parse HEAD`
    echo "         FROM: $CURRENT ($CURRENT_COMMIT_ID)"
    # COMMIT_ID either was  previously set with -b option, or is an empty string
    CHECKOUT_ID=$COMMIT_ID
    [ -z "$CHECKOUT_ID" ] && [ "$BRANCH" == "HEAD" ] && CHECKOUT_ID="tags/$LATEST_STABLE_DEVOPS"
    [ -z "$CHECKOUT_ID" ] && [ "$BRANCH" != "HEAD" ] && CHECKOUT_ID="$BRANCH"
    if [[ $CHECKOUT_ID == "tags/"* ]]; then
        REMOTE_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-list -n 1 $CHECKOUT_ID`
    else
        REMOTE_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-parse origin/$CHECKOUT_ID`
    fi
    echo "         TO: $CHECKOUT_ID ($REMOTE_COMMIT_ID)"
    if [ "$CURRENT_COMMIT_ID" == "$REMOTE_COMMIT_ID" ]; then
        echo "         Nothing to be done."
    else
        echo "         Update required."
        lxc exec $CONTAINER -- service osm-ro stop
        lxc exec $CONTAINER -- git -C /opt/openmano stash
        lxc exec $CONTAINER -- git -C /opt/openmano pull --rebase
        lxc exec $CONTAINER -- git -C /opt/openmano checkout $CHECKOUT_ID
        lxc exec $CONTAINER -- git -C /opt/openmano stash pop
        lxc exec $CONTAINER -- /opt/openmano/database_utils/migrate_mano_db.sh
        lxc exec $CONTAINER -- service osm-ro start
    fi
    echo

    echo -e "     Updating SO and UI"
    CONTAINER="SO-ub"
    MDG="SO"
    INSTALL_FOLDER=""   # To be filled in
    echo -e "     Fetching the repo"
    lxc exec $CONTAINER -- git -C $INSTALL_FOLDER fetch --all
    BRANCH=""
    BRANCH=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER status -sb | head -n1 | sed -n 's/^## \(.*\).*/\1/p'|awk '{print $1}' |sed 's/\(.*\)\.\.\..*/\1/'`
    [ -z "$BRANCH" ] && FATAL "Could not find the current branch in use in the '$MDG'"
    CURRENT=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER status |head -n1`
    CURRENT_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-parse HEAD`
    echo "         FROM: $CURRENT ($CURRENT_COMMIT_ID)"
    # COMMIT_ID either was  previously set with -b option, or is an empty string
    CHECKOUT_ID=$COMMIT_ID
    [ -z "$CHECKOUT_ID" ] && [ "$BRANCH" == "HEAD" ] && CHECKOUT_ID="tags/$LATEST_STABLE_DEVOPS"
    [ -z "$CHECKOUT_ID" ] && [ "$BRANCH" != "HEAD" ] && CHECKOUT_ID="$BRANCH"
    if [[ $CHECKOUT_ID == "tags/"* ]]; then
        REMOTE_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-list -n 1 $CHECKOUT_ID`
    else
        REMOTE_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-parse origin/$CHECKOUT_ID`
    fi
    echo "         TO: $CHECKOUT_ID ($REMOTE_COMMIT_ID)"
    if [ "$CURRENT_COMMIT_ID" == "$REMOTE_COMMIT_ID" ]; then
        echo "         Nothing to be done."
    else
        echo "         Update required."
        # Instructions to be added
        # lxc exec SO-ub -- ...
    fi
    echo
    echo -e "Updating MON Container"
    CONTAINER="MON"
    MDG="MON"
    INSTALL_FOLDER="/root/MON"
    echo -e "     Fetching the repo"
    lxc exec $CONTAINER -- git -C $INSTALL_FOLDER fetch --all
    BRANCH=""
    BRANCH=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER status -sb | head -n1 | sed -n 's/^## \(.*\).*/\1/p'|awk '{print $1}' |sed 's/\(.*\)\.\.\..*/\1/'`
    [ -z "$BRANCH" ] && FATAL "Could not find the current branch in use in the '$MDG'"
    CURRENT=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER status |head -n1`
    CURRENT_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-parse HEAD`
    echo "         FROM: $CURRENT ($CURRENT_COMMIT_ID)"
    # COMMIT_ID either was  previously set with -b option, or is an empty string
    CHECKOUT_ID=$COMMIT_ID
    [ -z "$CHECKOUT_ID" ] && [ "$BRANCH" == "HEAD" ] && CHECKOUT_ID="tags/$LATEST_STABLE_DEVOPS"
    [ -z "$CHECKOUT_ID" ] && [ "$BRANCH" != "HEAD" ] && CHECKOUT_ID="$BRANCH"
    if [[ $CHECKOUT_ID == "tags/"* ]]; then
        REMOTE_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-list -n 1 $CHECKOUT_ID`
    else
        REMOTE_COMMIT_ID=`lxc exec $CONTAINER -- git -C $INSTALL_FOLDER rev-parse origin/$CHECKOUT_ID`
    fi
    echo "         TO: $CHECKOUT_ID ($REMOTE_COMMIT_ID)"
    if [ "$CURRENT_COMMIT_ID" == "$REMOTE_COMMIT_ID" ]; then
        echo "         Nothing to be done."
    else
        echo "         Update required."
    fi
    echo
}

function so_is_up() {
    if [ -n "$1" ]; then
        SO_IP=$1
    else
        SO_IP=`lxc list SO-ub -c 4|grep eth0 |awk '{print $2}'`
    fi
    time=0
    step=5
    timelength=300
    while [ $time -le $timelength ]
    do
        if [[ `curl -k -X GET   https://$SO_IP:8008/api/operational/vcs/info \
                -H 'accept: application/vnd.yang.data+json' \
                -H 'authorization: Basic YWRtaW46YWRtaW4=' \
                -H 'cache-control: no-cache' 2> /dev/null | jq  '.[].components.component_info[] | select(.component_name=="RW.Restconf")' 2>/dev/null | grep "RUNNING" | wc -l` -eq 1 ]]
        then
            echo "RW.Restconf running....SO is up"
            return 0
        fi

        sleep $step
        echo -n "."
        time=$((time+step))
    done

    FATAL "OSM Failed to startup. SO failed to startup"
}

function vca_is_up() {
    if [[ `lxc exec VCA -- juju status | grep "osm" | wc -l` -eq 1 ]]; then
            echo "VCA is up and running"
            return 0
    fi

    FATAL "OSM Failed to startup. VCA failed to startup"
}

function mon_is_up() {
    if [[ `curl http://$RO_IP:9090/openmano/ | grep "works" | wc -l` -eq 1 ]]; then
            echo "MON is up and running"
            return 0
    fi

    FATAL "OSM Failed to startup. MON failed to startup"
}

function ro_is_up() {
    if [ -n "$1" ]; then
        RO_IP=$1
    else
        RO_IP=`lxc list RO -c 4|grep eth0 |awk '{print $2}'`
    fi
    time=0
    step=2
    timelength=20
    while [ $time -le $timelength ]; do
        if [[ `curl http://$RO_IP:9090/openmano/ | grep "works" | wc -l` -eq 1 ]]; then
            echo "RO is up and running"
            return 0
        fi
        sleep $step
        echo -n "."
        time=$((time+step))
    done

    FATAL "OSM Failed to startup. RO failed to startup"
}


function configure_RO(){
    . $OSM_DEVOPS/installers/export_ips
    echo -e "       Configuring RO"
    lxc exec RO -- sed -i -e "s/^\#\?log_socket_host:.*/log_socket_host: $SO_CONTAINER_IP/g" /etc/osm/openmanod.cfg
    lxc exec RO -- service osm-ro restart

    ro_is_up

    lxc exec RO -- openmano tenant-delete -f osm >/dev/null
    lxc exec RO -- openmano tenant-create osm > /dev/null
    lxc exec RO -- sed -i '/export OPENMANO_TENANT=osm/d' .bashrc
    lxc exec RO -- sed -i '$ i export OPENMANO_TENANT=osm' .bashrc
    lxc exec RO -- sh -c 'echo "export OPENMANO_TENANT=osm" >> .bashrc'
}

function configure_VCA(){
    echo -e "       Configuring VCA"
    JUJU_PASSWD=$(generate_secret)
    echo -e "$JUJU_PASSWD\n$JUJU_PASSWD" | lxc exec VCA -- juju change-user-password
}

function configure_SOUI(){
    . $OSM_DEVOPS/installers/export_ips
    JUJU_CONTROLLER_IP=`lxc exec VCA -- lxc list -c 4 |grep eth0 |awk '{print $2}'`
    RO_TENANT_ID=`lxc exec RO -- openmano tenant-list osm |awk '{print $1}'`

    echo -e " Configuring MON"
    #Information to be added about SO socket for logging

    echo -e "       Configuring SO"
    sudo route add -host $JUJU_CONTROLLER_IP gw $VCA_CONTAINER_IP
    sudo ip route add 10.44.127.0/24 via $VCA_CONTAINER_IP
    sudo sed -i "$ i route add -host $JUJU_CONTROLLER_IP gw $VCA_CONTAINER_IP" /etc/rc.local
    sudo sed -i "$ i ip route add 10.44.127.0/24 via $VCA_CONTAINER_IP" /etc/rc.local
    # make journaling persistent
    lxc exec SO-ub -- mkdir -p /var/log/journal
    lxc exec SO-ub -- systemd-tmpfiles --create --prefix /var/log/journal
    lxc exec SO-ub -- systemctl restart systemd-journald

    echo RIFT_EXTERNAL_ADDRESS=$DEFAULT_IP | lxc exec SO-ub -- tee -a /usr/rift/etc/default/launchpad

    lxc exec SO-ub -- systemctl restart launchpad

    so_is_up $SO_CONTAINER_IP

    #delete existing config agent (could be there on reconfigure)
    curl -k --request DELETE \
      --url https://$SO_CONTAINER_IP:8008/api/config/config-agent/account/osmjuju \
      --header 'accept: application/vnd.yang.data+json' \
      --header 'authorization: Basic YWRtaW46YWRtaW4=' \
      --header 'cache-control: no-cache' \
      --header 'content-type: application/vnd.yang.data+json' &> /dev/null

    result=$(curl -k --request POST \
      --url https://$SO_CONTAINER_IP:8008/api/config/config-agent \
      --header 'accept: application/vnd.yang.data+json' \
      --header 'authorization: Basic YWRtaW46YWRtaW4=' \
      --header 'cache-control: no-cache' \
      --header 'content-type: application/vnd.yang.data+json' \
      --data '{"account": [ { "name": "osmjuju", "account-type": "juju", "juju": { "ip-address": "'$JUJU_CONTROLLER_IP'", "port": "17070", "user": "admin", "secret": "'$JUJU_PASSWD'" }  }  ]}')
    [[ $result =~ .*success.* ]] || FATAL "Failed config-agent configuration: $result"

    #R1/R2 config line
    #result=$(curl -k --request PUT \
    #  --url https://$SO_CONTAINER_IP:8008/api/config/resource-orchestrator \
    #  --header 'accept: application/vnd.yang.data+json' \
    #  --header 'authorization: Basic YWRtaW46YWRtaW4=' \
    #  --header 'cache-control: no-cache' \
    #  --header 'content-type: application/vnd.yang.data+json' \
    #  --data '{ "openmano": { "host": "'$RO_CONTAINER_IP'", "port": "9090", "tenant-id": "'$RO_TENANT_ID'" }, "name": "osmopenmano", "account-type": "openmano" }')

    result=$(curl -k --request PUT \
      --url https://$SO_CONTAINER_IP:8008/api/config/project/default/ro-account/account \
      --header 'accept: application/vnd.yang.data+json' \
      --header 'authorization: Basic YWRtaW46YWRtaW4=' \
      --header 'cache-control: no-cache'   \
      --header 'content-type: application/vnd.yang.data+json' \
      --data '{"rw-ro-account:account": [ { "openmano": { "host": "'$RO_CONTAINER_IP'", "port": "9090", "tenant-id": "'$RO_TENANT_ID'"}, "name": "osmopenmano", "ro-account-type": "openmano" }]}')
    [[ $result =~ .*success.* ]] || FATAL "Failed resource-orchestrator configuration: $result"

    result=$(curl -k --request PATCH \
      --url https://$SO_CONTAINER_IP:8008/v2/api/config/openidc-provider-config/rw-ui-client/redirect-uri \
      --header 'accept: application/vnd.yang.data+json' \
      --header 'authorization: Basic YWRtaW46YWRtaW4=' \
      --header 'cache-control: no-cache'   \
      --header 'content-type: application/vnd.yang.data+json' \
      --data '{"redirect-uri": "https://'$DEFAULT_IP':8443/callback" }')
    [[ $result =~ .*success.* ]] || FATAL "Failed redirect-uri configuration: $result"

    result=$(curl -k --request PATCH \
      --url https://$SO_CONTAINER_IP:8008/v2/api/config/openidc-provider-config/rw-ui-client/post-logout-redirect-uri \
      --header 'accept: application/vnd.yang.data+json' \
      --header 'authorization: Basic YWRtaW46YWRtaW4=' \
      --header 'cache-control: no-cache'   \
      --header 'content-type: application/vnd.yang.data+json' \
      --data '{"post-logout-redirect-uri": "https://'$DEFAULT_IP':8443/?api_server=https://'$DEFAULT_IP'" }')
    [[ $result =~ .*success.* ]] || FATAL "Failed post-logout-redirect-uri configuration: $result"

    lxc exec SO-ub -- tee /etc/network/interfaces.d/60-rift.cfg <<EOF
auto lo:1
iface lo:1 inet static
        address  $DEFAULT_IP
        netmask 255.255.255.255
EOF
    lxc exec SO-ub ifup lo:1
}

#Configure RO, VCA, and SO with the initial configuration:
#  RO -> tenant:osm, logs to be sent to SO
#  VCA -> juju-password
#  SO -> route to Juju Controller, add RO account, add VCA account
function configure(){
    #Configure components
    echo -e "\nConfiguring components"
    configure_RO
    configure_VCA
    configure_SOUI
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

function launch_container_from_lxd(){
    export OSM_MDG=$1
    OSM_load_config
    export OSM_BASE_IMAGE=$2
    if ! container_exists $OSM_BUILD_CONTAINER; then
        CONTAINER_OPTS=""
        [[ "$OSM_BUILD_CONTAINER_PRIVILEGED" == yes ]] && CONTAINER_OPTS="$CONTAINER_OPTS -c security.privileged=true"
        [[ "$OSM_BUILD_CONTAINER_ALLOW_NESTED" == yes ]] && CONTAINER_OPTS="$CONTAINER_OPTS -c security.nesting=true"
        create_container $OSM_BASE_IMAGE $OSM_BUILD_CONTAINER $CONTAINER_OPTS
        wait_container_up $OSM_BUILD_CONTAINER
    fi
}

function install_osmclient(){
    CLIENT_RELEASE=${RELEASE#"-R "}
    CLIENT_REPOSITORY_KEY="OSM%20ETSI%20Release%20Key.gpg"
    CLIENT_REPOSITORY=${REPOSITORY#"-r "}
    CLIENT_REPOSITORY_BASE=${REPOSITORY_BASE#"-u "}
    key_location=$CLIENT_REPOSITORY_BASE/$CLIENT_RELEASE/$CLIENT_REPOSITORY_KEY
    curl $key_location | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=amd64] $CLIENT_REPOSITORY_BASE/$CLIENT_RELEASE $CLIENT_REPOSITORY osmclient"
    sudo apt-get update
    sudo apt-get install -y python-pip
    sudo -H LC_ALL=C pip install pip==9.0.3
    sudo -H LC_ALL=C pip install python-magic
    sudo apt-get install -y python-osmclient
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

function install_from_lxdimages(){
    LXD_RELEASE=${RELEASE#"-R "}
    if [ -n "$LXD_REPOSITORY_PATH" ]; then
        LXD_IMAGE_DIR="$LXD_REPOSITORY_PATH"
    else
        LXD_IMAGE_DIR="$(mktemp -d -q --tmpdir "osmimages.XXXXXX")"
        trap 'rm -rf "$LXD_IMAGE_DIR"' EXIT
    fi
    echo -e "\nDeleting previous lxd images if they exist"
    lxc image show osm-ro &>/dev/null && lxc image delete osm-ro
    lxc image show osm-vca &>/dev/null && lxc image delete osm-vca
    lxc image show osm-soui &>/dev/null && lxc image delete osm-soui
    echo -e "\nImporting osm-ro"
    [ -z "$LXD_REPOSITORY_PATH" ] && wget -O $LXD_IMAGE_DIR/osm-ro.tar.gz $LXD_REPOSITORY_BASE/$LXD_RELEASE/osm-ro.tar.gz
    lxc image import $LXD_IMAGE_DIR/osm-ro.tar.gz --alias osm-ro
    rm -f $LXD_IMAGE_DIR/osm-ro.tar.gz
    echo -e "\nImporting osm-vca"
    [ -z "$LXD_REPOSITORY_PATH" ] && wget -O $LXD_IMAGE_DIR/osm-vca.tar.gz $LXD_REPOSITORY_BASE/$LXD_RELEASE/osm-vca.tar.gz
    lxc image import $LXD_IMAGE_DIR/osm-vca.tar.gz --alias osm-vca
    rm -f $LXD_IMAGE_DIR/osm-vca.tar.gz
    echo -e "\nImporting osm-soui"
    [ -z "$LXD_REPOSITORY_PATH" ] && wget -O $LXD_IMAGE_DIR/osm-soui.tar.gz $LXD_REPOSITORY_BASE/$LXD_RELEASE/osm-soui.tar.gz
    lxc image import $LXD_IMAGE_DIR/osm-soui.tar.gz --alias osm-soui
    rm -f $LXD_IMAGE_DIR/osm-soui.tar.gz
    launch_container_from_lxd RO osm-ro
    ro_is_up && track RO
    launch_container_from_lxd VCA osm-vca
    vca_is_up && track VCA
    launch_container_from_lxd MON osm-mon
    mon_is_up && track MON
    launch_container_from_lxd SO osm-soui
    #so_is_up && track SOUI
    track SOUI
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
    echo "Finished installation of juju"
    return 0
}

function juju_createcontroller() {
    if ! juju show-controller $OSM_STACK_NAME &> /dev/null; then
        # Not found created, create the controller
        sg lxd -c "juju bootstrap --bootstrap-series=xenial localhost $OSM_STACK_NAME"
    fi
    [ $(juju controllers | awk "/^${OSM_STACK_NAME}[\*| ]/{print $1}"|wc -l) -eq 1 ] || FATAL "Juju installation failed"
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
        sg docker -c "docker build ${LWTEMPDIR}/RO -f ${LWTEMPDIR}/RO/docker/Dockerfile-local -t ${DOCKER_USER}/ro --no-cache" || FATAL "cannot build RO docker image"
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

function generate_config_log_folders() {
    echo "Generating config and log folders"
    $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/docker-compose.yaml $OSM_DOCKER_WORK_DIR/docker-compose.yaml
    $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/prometheus.yml $OSM_DOCKER_WORK_DIR/prometheus.yml
    echo "Finished generation of config and log folders"
}

function generate_docker_env_files() {
    echo "Generating docker env files"
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
        $WORKDIR_SUDO sed -i "s|OSMLCM_VCA_PUBKEY.*|OSMLCM_VCA_PUBKEY=$OSM_VCA_PUBKEY|g" $OSM_DOCKER_WORK_DIR/lcm.env
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
    OSM_PROM_HOSTPORT=9091
    [ -n "$INSTALL_ELK" ] && OSM_ELK_PORT=5601
    [ -n "$INSTALL_PERFMON" ] && OSM_PM_PORT=3000

    if [ -n "$NO_HOST_PORTS" ]; then
        OSM_PORTS+=(OSM_NBI_PORTS=$OSM_NBI_PORT)
        OSM_PORTS+=(OSM_RO_PORTS=$OSM_RO_PORT)
        OSM_PORTS+=(OSM_KEYSTONE_PORTS=$OSM_KEYSTONE_PORT)
        OSM_PORTS+=(OSM_UI_PORTS=$OSM_UI_PORT)
        OSM_PORTS+=(OSM_MON_PORTS=$OSM_MON_PORT)
        OSM_PORTS+=(OSM_PROM_PORTS=$OSM_PROM_PORT)
        [ -n "$INSTALL_PERFMON" ] && OSM_PORTS+=(OSM_PM_PORTS=$OSM_PM_PORT)
        [ -n "$INSTALL_ELK" ] && OSM_PORTS+=(OSM_ELK_PORTS=$OSM_ELK_PORT)
    else
        OSM_PORTS+=(OSM_NBI_PORTS=$OSM_NBI_PORT:$OSM_NBI_PORT)
        OSM_PORTS+=(OSM_RO_PORTS=$OSM_RO_PORT:$OSM_RO_PORT)
        OSM_PORTS+=(OSM_KEYSTONE_PORTS=$OSM_KEYSTONE_PORT:$OSM_KEYSTONE_PORT)
        OSM_PORTS+=(OSM_UI_PORTS=$OSM_UI_PORT:$OSM_UI_PORT)
        OSM_PORTS+=(OSM_MON_PORTS=$OSM_MON_PORT:$OSM_MON_PORT)
        OSM_PORTS+=(OSM_PROM_PORTS=$OSM_PROM_HOSTPORT:$OSM_PROM_PORT)
        [ -n "$INSTALL_PERFMON" ] && OSM_PORTS+=(OSM_PM_PORTS=$OSM_PM_PORT:$OSM_PM_PORT)
        [ -n "$INSTALL_ELK" ] && OSM_PORTS+=(OSM_ELK_PORTS=$OSM_ELK_PORT:$OSM_ELK_PORT)
    fi
    echo "export ${OSM_PORTS[@]}" | $WORKDIR_SUDO tee $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export OSM_NETWORK=net${OSM_STACK_NAME}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export TAG=${OSM_DOCKER_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export DOCKER_USER=${DOCKER_USER}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export KAFKA_TAG=${KAFKA_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export PROMETHEUS_TAG=${PROMETHEUS_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh
    echo "export KEYSTONEDB_TAG=${KEYSTONEDB_TAG}" | $WORKDIR_SUDO tee --append $OSM_DOCKER_WORK_DIR/osm_ports.sh

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

function deploy_perfmon() {
    echo "Pulling docker images for PM (Grafana)"
    sg docker -c "docker pull grafana/grafana" || FATAL "cannot get grafana docker image"
    echo "Finished pulling PM docker images"
    $WORKDIR_SUDO mkdir -p $OSM_DOCKER_WORK_DIR/osm_metrics
    $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/osm_metrics/*.yml $OSM_DOCKER_WORK_DIR/osm_metrics
    $WORKDIR_SUDO cp -b ${OSM_DEVOPS}/installers/docker/osm_metrics/*.json $OSM_DOCKER_WORK_DIR/osm_metrics
    remove_stack osm_metrics
    echo "Deploying PM stack (Grafana)"
    sg docker -c "OSM_NETWORK=net${OSM_STACK_NAME} docker stack deploy -c $OSM_DOCKER_WORK_DIR/osm_metrics/docker-compose.yml osm_metrics"
    echo "Finished deployment of PM stack"
    return 0
}

function install_lightweight() {
    [ "${OSM_STACK_NAME}" == "osm" ] || OSM_DOCKER_WORK_DIR="$OSM_WORK_DIR/stack/$OSM_STACK_NAME"
    [ ! -d "$OSM_DOCKER_WORK_DIR" ] && $WORKDIR_SUDO mkdir -p $OSM_DOCKER_WORK_DIR

    track checkingroot
    [ "$USER" == "root" ] && FATAL "You are running the installer as root. The installer is prepared to be executed as a normal user with sudo privileges."
    track noroot
    [ -z "$ASSUME_YES" ] && ! ask_user "The installation will configure LXD, install juju, install docker CE and init a docker swarm, as pre-requirements. Do you want to proceed (Y/n)? " y && echo "Cancelled!" && exit 1
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
    if [ -z "$OSM_DATABASE_COMMONKEY" ]; then
        OSM_DATABASE_COMMONKEY=$(generate_secret)
        [ -z "OSM_DATABASE_COMMONKEY" ] && FATAL "Cannot generate common db secret"
    fi

    track juju
    [ -n "$INSTALL_NODOCKER" ] || install_docker_ce
    track docker_ce
    #install_docker_compose
    [ -n "$INSTALL_NODOCKER" ] || init_docker_swarm
    track docker_swarm
    [ -z "$DOCKER_NOBUILD" ] && generate_docker_images
    track docker_build
    generate_docker_env_files
    generate_config_log_folders

    # remove old stack
    remove_stack $OSM_STACK_NAME
    create_docker_network
    deploy_lightweight
    generate_osmclient_script
    track docker_deploy
    [ -n "$INSTALL_VIMEMU" ] && install_vimemu && track vimemu
    [ -n "$INSTALL_ELK" ] && deploy_elk && track elk
    [ -n "$INSTALL_PERFMON" ] && deploy_perfmon && track perfmon
    [ -z "$INSTALL_NOHOSTCLIENT" ] && install_osmclient
    track osmclient
    wget -q -O- https://osm-download.etsi.org/ftp/osm-6.0-six/sixME2.txt &> /dev/null
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

function dump_vars(){
    echo "DEVELOP=$DEVELOP"
    echo "INSTALL_FROM_SOURCE=$INSTALL_FROM_SOURCE"
    echo "UNINSTALL=$UNINSTALL"
    echo "NAT=$NAT"
    echo "UPDATE=$UPDATE"
    echo "RECONFIGURE=$RECONFIGURE"
    echo "TEST_INSTALLER=$TEST_INSTALLER"
    echo "INSTALL_VIMEMU=$INSTALL_VIMEMU"
    echo "INSTALL_LXD=$INSTALL_LXD"
    echo "INSTALL_FROM_LXDIMAGES=$INSTALL_FROM_LXDIMAGES"
    echo "LXD_REPOSITORY_BASE=$LXD_REPOSITORY_BASE"
    echo "LXD_REPOSITORY_PATH=$LXD_REPOSITORY_PATH"
    echo "INSTALL_LIGHTWEIGHT=$INSTALL_LIGHTWEIGHT"
    echo "INSTALL_ONLY=$INSTALL_ONLY"
    echo "INSTALL_ELK=$INSTALL_ELK"
    echo "INSTALL_PERFMON=$INSTALL_PERFMON"
    echo "TO_REBUILD=$TO_REBUILD"
    echo "INSTALL_NOLXD=$INSTALL_NOLXD"
    echo "INSTALL_NODOCKER=$INSTALL_NODOCKER"
    echo "INSTALL_NOJUJU=$INSTALL_NOJUJU"
    echo "RELEASE=$RELEASE"
    echo "REPOSITORY=$REPOSITORY"
    echo "REPOSITORY_BASE=$REPOSITORY_BASE"
    echo "REPOSITORY_KEY=$REPOSITORY_KEY"
    echo "NOCONFIGURE=$NOCONFIGURE"
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
NAT=""
UPDATE=""
RECONFIGURE=""
TEST_INSTALLER=""
INSTALL_LXD=""
SHOWOPTS=""
COMMIT_ID=""
ASSUME_YES=""
INSTALL_FROM_SOURCE=""
RELEASE="ReleaseSIX"
REPOSITORY="stable"
INSTALL_VIMEMU=""
INSTALL_FROM_LXDIMAGES=""
LXD_REPOSITORY_BASE="https://osm-download.etsi.org/repository/osm/lxd"
LXD_REPOSITORY_PATH=""
INSTALL_LIGHTWEIGHT="y"
INSTALL_ONLY=""
INSTALL_ELK=""
INSTALL_PERFMON=""
TO_REBUILD=""
INSTALL_NOLXD=""
INSTALL_NODOCKER=""
INSTALL_NOJUJU=""
INSTALL_NOHOSTCLIENT=""
NOCONFIGURE=""
RELEASE_DAILY=""
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
OSM_DOCKER_TAG=latest
DOCKER_USER=opensourcemano
PULL_IMAGES="y"
KAFKA_TAG=2.11-1.0.2
PROMETHEUS_TAG=v2.4.3
KEYSTONEDB_TAG=10
OSM_DATABASE_COMMONKEY=
ELASTIC_VERSION=6.4.2
ELASTIC_CURATOR_VERSION=5.5.4

while getopts ":hy-:b:r:k:u:R:l:p:D:o:m:H:S:s:w:t:U:P:" o; do
    case "${o}" in
        h)
            usage && exit 0
            ;;
        b)
            COMMIT_ID=${OPTARG}
            PULL_IMAGES=""
            ;;
        r)
            REPOSITORY="${OPTARG}"
            REPO_ARGS+=(-r "$REPOSITORY")
            ;;
        R)
            RELEASE="${OPTARG}"
            REPO_ARGS+=(-R "$RELEASE")
            ;;
        k)
            REPOSITORY_KEY="${OPTARG}"
            REPO_ARGS+=(-k "$REPOSITORY_KEY")
            ;;
        u)
            REPOSITORY_BASE="${OPTARG}"
            REPO_ARGS+=(-u "$REPOSITORY_BASE")
            ;;
        U)
            DOCKER_USER="${OPTARG}"
            ;;
        l)
            LXD_REPOSITORY_BASE="${OPTARG}"
            ;;
        p)
            LXD_REPOSITORY_PATH="${OPTARG}"
            ;;
        D)
            OSM_DEVOPS="${OPTARG}"
            ;;
        s)
            OSM_STACK_NAME="${OPTARG}"
            ;;
        H)
            OSM_VCA_HOST="${OPTARG}"
            ;;
        S)
            OSM_VCA_SECRET="${OPTARG}"
            ;;
        P)
            OSM_VCA_PUBKEY=$(cat ${OPTARG})
            ;;
        w)
            # when specifying workdir, do not use sudo for access
            WORKDIR_SUDO=
            OSM_WORK_DIR="${OPTARG}"
            ;;
        t)
            OSM_DOCKER_TAG="${OPTARG}"
            ;;
        o)
            INSTALL_ONLY="y"
            [ "${OPTARG}" == "vimemu" ] && INSTALL_VIMEMU="y" && continue
            [ "${OPTARG}" == "elk_stack" ] && INSTALL_ELK="y" && continue
            [ "${OPTARG}" == "pm_stack" ] && INSTALL_PERFMON="y" && continue
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
            [ "${OPTARG}" == "KEYSTONE-DB" ] && TO_REBUILD="$TO_REBUILD KEYSTONE-DB" && continue
            [ "${OPTARG}" == "NONE" ] && TO_REBUILD="$TO_REBUILD NONE" && continue
            ;;
        -)
            [ "${OPTARG}" == "help" ] && usage && exit 0
            [ "${OPTARG}" == "source" ] && INSTALL_FROM_SOURCE="y" && PULL_IMAGES="" && continue
            [ "${OPTARG}" == "develop" ] && DEVELOP="y" && continue
            [ "${OPTARG}" == "uninstall" ] && UNINSTALL="y" && continue
            [ "${OPTARG}" == "nat" ] && NAT="y" && continue
            [ "${OPTARG}" == "update" ] && UPDATE="y" && continue
            [ "${OPTARG}" == "reconfigure" ] && RECONFIGURE="y" && continue
            [ "${OPTARG}" == "test" ] && TEST_INSTALLER="y" && continue
            [ "${OPTARG}" == "lxdinstall" ] && INSTALL_LXD="y" && continue
            [ "${OPTARG}" == "nolxd" ] && INSTALL_NOLXD="y" && continue
            [ "${OPTARG}" == "nodocker" ] && INSTALL_NODOCKER="y" && continue
            [ "${OPTARG}" == "lxdimages" ] && INSTALL_FROM_LXDIMAGES="y" && continue
            [ "${OPTARG}" == "lightweight" ] && INSTALL_LIGHTWEIGHT="y" && continue
            [ "${OPTARG}" == "soui" ] && INSTALL_LIGHTWEIGHT="" && RELEASE="-R ReleaseTHREE" && REPOSITORY="-r stable" && continue
            [ "${OPTARG}" == "vimemu" ] && INSTALL_VIMEMU="y" && continue
            [ "${OPTARG}" == "elk_stack" ] && INSTALL_ELK="y" && continue
            [ "${OPTARG}" == "pm_stack" ] && INSTALL_PERFMON="y" && continue
            [ "${OPTARG}" == "noconfigure" ] && NOCONFIGURE="y" && continue
            [ "${OPTARG}" == "showopts" ] && SHOWOPTS="y" && continue
            [ "${OPTARG}" == "daily" ] && RELEASE_DAILY="y" && continue
            [ "${OPTARG}" == "nohostports" ] && NO_HOST_PORTS="y" && continue
            [ "${OPTARG}" == "nojuju" ] && INSTALL_NOJUJU="y" && continue
            [ "${OPTARG}" == "nodockerbuild" ] && DOCKER_NOBUILD="y" && continue
            [ "${OPTARG}" == "nohostclient" ] && INSTALL_NOHOSTCLIENT="y" && continue
            [ "${OPTARG}" == "pullimages" ] && continue
            echo -e "Invalid option: '--$OPTARG'\n" >&2
            usage && exit 1
            ;;
        \?)
            echo -e "Invalid option: '-$OPTARG'\n" >&2
            usage && exit 1
            ;;
        y)
            ASSUME_YES="y"
            ;;
        *)
            usage && exit 1
            ;;
    esac
done

[ -n "$INSTALL_FROM_LXDIMAGES" ] && [ -n "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible options: --lxd can only be used with --soui"
[ -n "$NAT" ] && [ -n "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible options: --nat can only be used with --soui"
[ -n "$NOCONFIGURE" ] && [ -n "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible options: --noconfigure can only be used with --soui"
[ -n "$RELEASE_DAILY" ] && [ -n "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible options: --daily can only be used with --soui"
[ -n "$INSTALL_NOLXD" ] && [ -z "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible option: --nolxd cannot be used with --soui"
[ -n "$INSTALL_NODOCKER" ] && [ -z "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible option: --nodocker cannot be used with --soui"
[ -n "$TO_REBUILD" ] && [ -z "$INSTALL_LIGHTWEIGHT" ] && FATAL "Incompatible option: -m cannot be used with --soui"
[ -n "$TO_REBUILD" ] && [ "$TO_REBUILD" != " NONE" ] && echo $TO_REBUILD | grep -q NONE && FATAL "Incompatible option: -m NONE cannot be used with other -m options"

if [ -n "$SHOWOPTS" ]; then
    dump_vars
    exit 0
fi

[ -n "$RELEASE_DAILY" ] && echo -e "\nInstalling from daily build repo" && RELEASE="-R ReleaseTHREE-daily" && REPOSITORY="-r testing" && COMMIT_ID="master"

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

OSM_JENKINS="$OSM_DEVOPS/jenkins"
. $OSM_JENKINS/common/all_funcs

[ -n "$INSTALL_LIGHTWEIGHT" ] && [ -n "$UNINSTALL" ] && uninstall_lightweight && echo -e "\nDONE" && exit 0
[ -n "$UNINSTALL" ] && uninstall && echo -e "\nDONE" && exit 0
[ -n "$NAT" ] && nat && echo -e "\nDONE" && exit 0
[ -n "$UPDATE" ] && update && echo -e "\nDONE" && exit 0
[ -n "$RECONFIGURE" ] && configure && echo -e "\nDONE" && exit 0
[ -n "$INSTALL_ONLY" ] && [ -n "$INSTALL_ELK" ] && deploy_elk
[ -n "$INSTALL_ONLY" ] && [ -n "$INSTALL_PERFMON" ] && deploy_perfmon
[ -n "$INSTALL_ONLY" ] && [ -n "$INSTALL_VIMEMU" ] && install_vimemu
[ -n "$INSTALL_ONLY" ] && echo -e "\nDONE" && exit 0

#Installation starts here
wget -q -O- https://osm-download.etsi.org/ftp/osm-6.0-six/README.txt &> /dev/null
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
if [ -n "$INSTALL_FROM_SOURCE" ]; then #install from source
    echo -e "\nCreating the containers and building from source ..."
    $OSM_DEVOPS/jenkins/host/start_build RO --notest checkout $COMMIT_ID || FATAL "RO container build failed (refspec: '$COMMIT_ID')"
    ro_is_up && track RO
    $OSM_DEVOPS/jenkins/host/start_build VCA || FATAL "VCA container build failed"
    vca_is_up && track VCA
    $OSM_DEVOPS/jenkins/host/start_build MON || FATAL "MON install failed"
    mon_is_up && track MON
    $OSM_DEVOPS/jenkins/host/start_build SO checkout $COMMIT_ID || FATAL "SO container build failed (refspec: '$COMMIT_ID')"
    $OSM_DEVOPS/jenkins/host/start_build UI checkout $COMMIT_ID || FATAL "UI container build failed (refspec: '$COMMIT_ID')"
    #so_is_up && track SOUI
    track SOUI
elif [ -n "$INSTALL_FROM_LXDIMAGES" ]; then #install from LXD images stored in OSM repo
    echo -e "\nInstalling from lxd images ..."
    install_from_lxdimages
else #install from binaries
    echo -e "\nCreating the containers and installing from binaries ..."
    $OSM_DEVOPS/jenkins/host/install RO ${REPO_ARGS[@]} || FATAL "RO install failed"
    ro_is_up && track RO
    $OSM_DEVOPS/jenkins/host/start_build VCA || FATAL "VCA install failed"
    vca_is_up && track VCA
    $OSM_DEVOPS/jenkins/host/install MON || FATAL "MON build failed"
    mon_is_up && track MON
    $OSM_DEVOPS/jenkins/host/install SO ${REPO_ARGS[@]} || FATAL "SO install failed"
    $OSM_DEVOPS/jenkins/host/install UI ${REPO_ARGS[@]} || FATAL "UI install failed"
    #so_is_up && track SOUI
    track SOUI
fi

#Install iptables-persistent and configure NAT rules
[ -z "$NOCONFIGURE" ] && nat

#Configure components
[ -z "$NOCONFIGURE" ] && configure

#Install osmclient
[ -z "$NOCONFIGURE" ] && install_osmclient

#Install vim-emu (optional)
[ -n "$INSTALL_VIMEMU" ] && install_docker_ce && install_vimemu

wget -q -O- https://osm-download.etsi.org/ftp/osm-6.0-six/README2.txt &> /dev/null
track end
echo -e "\nDONE"
