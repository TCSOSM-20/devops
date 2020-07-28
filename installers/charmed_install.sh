#! /bin/bash
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

# set -eux

K8S_CLOUD_NAME="k8s-cloud"
KUBECTL="microk8s.kubectl"
IMAGES_OVERLAY_FILE=~/.osm/images-overlay.yaml
function check_arguments(){
    while [ $# -gt 0 ] ; do
        case $1 in
            --bundle) BUNDLE="$2" ;;
            --k8s) KUBECFG="$2" ;;
            --vca) CONTROLLER="$2" ;;
            --lxd) LXD_CLOUD="$2" ;;
            --lxd-cred) LXD_CREDENTIALS="$2" ;;
            --microstack) MICROSTACK=y ;;
            --ha) BUNDLE="osm-ha" ;;
            --tag) TAG="$2" ;;
        esac
        shift
    done

    # echo $BUNDLE $KUBECONFIG $LXDENDPOINT
}

function install_snaps(){
    if [ ! -v KUBECFG ]; then
        sudo snap install microk8s --classic
        sudo usermod -a -G microk8s `whoami`
        mkdir -p ~/.kube
        sudo chown -f -R `whoami` ~/.kube
        KUBEGRP="microk8s"
    else
        KUBECTL="kubectl"
        sudo snap install kubectl --classic
        export KUBECONFIG=${KUBECFG}
        KUBEGRP=$(id -g -n)
    fi
    sudo snap install juju --classic --channel=2.8/stable
}

function bootstrap_k8s_lxd(){
    [ -v CONTROLLER ] && ADD_K8S_OPTS="--controller ${CONTROLLER}" && CONTROLLER_NAME=$CONTROLLER
    [ ! -v CONTROLLER ] && ADD_K8S_OPTS="--client" && BOOTSTRAP_NEEDED="yes" && CONTROLLER_NAME="osm-vca"

    if [ -v BOOTSTRAP_NEEDED ]; then
        CONTROLLER_PRESENT=$(juju controllers 2>/dev/null| grep ${CONTROLLER_NAME} | wc -l)
        if [ $CONTROLLER_PRESENT -ge 1 ]; then
            cat << EOF
Threre is already a VCA present with the installer reserved name of "${CONTROLLER_NAME}".
You may either explicitly use this VCA with the "--vca ${CONTROLLER_NAME}" option, or remove it
using this command:

   juju destroy-controller --release-storage --destroy-all-models -y ${CONTROLLER_NAME}

Please retry the installation once this conflict has been resolved.
EOF
            exit 1
        fi
    fi

    if [ -v KUBECFG ]; then
        cat $KUBECFG | juju add-k8s $K8S_CLOUD_NAME $ADD_K8S_OPTS
        [ -v BOOTSTRAP_NEEDED ] && juju bootstrap $K8S_CLOUD_NAME $CONTROLLER_NAME --config controller-service-type=loadbalancer
    else
        sg ${KUBEGRP} -c "echo ${DEFAULT_IP}-${DEFAULT_IP} | microk8s.enable metallb"
        sg ${KUBEGRP} -c "microk8s.enable storage dns"
        TIME_TO_WAIT=30
        start_time="$(date -u +%s)"
        while true
        do
            now="$(date -u +%s)"
            if [[ $(( now - start_time )) -gt $TIME_TO_WAIT ]];then
                echo "Microk8s storage failed to enable"
                sg ${KUBEGRP} -c "microk8s.status"
                exit 1
            fi
            sg ${KUBEGRP} -c "microk8s.status" | grep 'storage: enabled'
            if [ $? -eq 0 ]; then
                break
            fi
            sleep 1
        done

        [ ! -v BOOTSTRAP_NEEDED ] && sg ${KUBEGRP} -c "microk8s.config" | juju add-k8s $K8S_CLOUD_NAME $ADD_K8S_OPTS
        [ -v BOOTSTRAP_NEEDED ] && sg ${KUBEGRP} -c "juju bootstrap microk8s $CONTROLLER_NAME --config controller-service-type=loadbalancer" && K8S_CLOUD_NAME=microk8s
    fi

    if [ -v LXD_CLOUD ]; then
        if [ ! -v LXD_CREDENTIALS ]; then
            echo "The installer needs the LXD server certificate if the LXD is external"
            exit 1
        fi
    else
        LXDENDPOINT=$DEFAULT_IP
        LXD_CLOUD=~/.osm/lxd-cloud.yaml
        LXD_CREDENTIALS=~/.osm/lxd-credentials.yaml
        # Apply sysctl production values for optimal performance
        sudo cp /usr/share/osm-devops/installers/60-lxd-production.conf /etc/sysctl.d/60-lxd-production.conf
        sudo sysctl --system
        # Install LXD snap
        sudo apt-get remove --purge -y liblxc1 lxc-common lxcfs lxd lxd-client
        sudo snap install lxd
        sudo apt-get install zfsutils-linux -y
        # Configure LXD
        sudo usermod -a -G lxd `whoami`
        cat /usr/share/osm-devops/installers/lxd-preseed.conf | sed 's/^config: {}/config:\n  core.https_address: '$LXDENDPOINT':8443/' | sg lxd -c "lxd init --preseed"
        sg lxd -c "lxd waitready"
        DEFAULT_MTU=$(ip addr show $DEFAULT_IF | perl -ne 'if (/mtu\s(\d+)/) {print $1;}')
        sg lxd -c "lxc profile device set default eth0 mtu $DEFAULT_MTU"
        sg lxd -c "lxc network set lxdbr0 bridge.mtu $DEFAULT_MTU"

        cat << EOF > $LXD_CLOUD
clouds:
  lxd-cloud:
    type: lxd
    auth-types: [certificate]
    endpoint: "https://$LXDENDPOINT:8443"
    config:
      ssl-hostname-verification: false
EOF
        openssl req -nodes -new -x509 -keyout ~/.osm/client.key -out ~/.osm/client.crt -days 365 -subj "/C=FR/ST=Nice/L=Nice/O=ETSI/OU=OSM/CN=osm.etsi.org"
        local server_cert=`cat /var/snap/lxd/common/lxd/server.crt | sed 's/^/        /'`
        local client_cert=`cat ~/.osm/client.crt | sed 's/^/        /'`
        local client_key=`cat ~/.osm/client.key | sed 's/^/        /'`

        cat << EOF > $LXD_CREDENTIALS
credentials:
  lxd-cloud:
    lxd-cloud:
      auth-type: certificate
      server-cert: |
$server_cert
      client-cert: |
$client_cert
      client-key: |
$client_key
EOF
        lxc config trust add local: ~/.osm/client.crt
    fi

    juju add-cloud -c $CONTROLLER_NAME lxd-cloud $LXD_CLOUD --force
    juju add-credential -c $CONTROLLER_NAME lxd-cloud -f $LXD_CREDENTIALS
    sg lxd -c "lxd waitready"
    #juju add-model test lxd-cloud || true
    juju controller-config features=[k8s-operators]
}

function wait_for_port(){
    SERVICE=$1
    INDEX=$2
    TIME_TO_WAIT=30
    start_time="$(date -u +%s)"
    while true
    do
        now="$(date -u +%s)"
        if [[ $(( now - start_time )) -gt $TIME_TO_WAIT ]];then
            echo "Failed to expose external ${SERVICE} interface port"
            exit 1
        fi

        if [ $(sg ${KUBEGRP} -c "${KUBECTL} get ingress -n osm -o json | jq -r '.items[$INDEX].metadata.name'") == ${SERVICE} ] ; then
            break
        fi
        sleep 1
    done
}

function deploy_charmed_osm(){
    create_overlay
    echo "Creating OSM model"
    if [ -v KUBECFG ]; then
        juju add-model osm $K8S_CLOUD_NAME
    else
        sg ${KUBEGRP} -c "juju add-model osm $K8S_CLOUD_NAME"
    fi
    echo "Deploying OSM with charms"
    images_overlay=""
    [ -v TAG ] && generate_images_overlay && images_overlay="--overlay $IMAGES_OVERLAY_FILE"
    if [ -v BUNDLE ]; then
        juju deploy $BUNDLE --overlay ~/.osm/vca-overlay.yaml $images_overlay
    else
        juju deploy osm --overlay ~/.osm/vca-overlay.yaml $images_overlay
    fi
    echo "Waiting for deployment to finish..."
    check_osm_deployed &> /dev/null
    echo "OSM with charms deployed"
    if [ ! -v KUBECFG ]; then
        sg ${KUBEGRP} -c "microk8s.enable ingress"
        API_SERVER=${DEFAULT_IP}
    else
        API_SERVER=$(kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " ")
        proto="$(echo $API_SERVER | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        url="$(echo ${API_SERVER/$proto/})"
        user="$(echo $url | grep @ | cut -d@ -f1)"
        hostport="$(echo ${url/$user@/} | cut -d/ -f1)"
        API_SERVER="$(echo $hostport | sed -e 's,:.*,,g')"
    fi

    juju config nbi-k8s juju-external-hostname=nbi.${API_SERVER}.xip.io
    juju expose nbi-k8s

    wait_for_port nbi-k8s 0
    sg ${KUBEGRP} -c "${KUBECTL} get ingress -n osm -o json | jq '.items[0].metadata.annotations += {\"nginx.ingress.kubernetes.io/backend-protocol\": \"HTTPS\"}' | ${KUBECTL} --validate=false replace -f -"
    sg ${KUBEGRP} -c "${KUBECTL} get ingress -n osm -o json | jq '.items[0].metadata.annotations += {\"nginx.ingress.kubernetes.io/proxy-body-size\": \"0\"}' | ${KUBECTL} replace -f -"

    juju config ng-ui juju-external-hostname=ngui.${API_SERVER}.xip.io
    juju expose ng-ui

    wait_for_port ng-ui 1
    sg ${KUBEGRP} -c "${KUBECTL} get ingress -n osm -o json | jq '.items[2].metadata.annotations += {\"nginx.ingress.kubernetes.io/proxy-body-size\": \"0\"}' | ${KUBECTL} replace -f -"

    juju config ui-k8s juju-external-hostname=osm.${API_SERVER}.xip.io
    juju expose ui-k8s

    wait_for_port ui-k8s 2
    sg ${KUBEGRP} -c "${KUBECTL} get ingress -n osm -o json | jq '.items[1].metadata.annotations += {\"nginx.ingress.kubernetes.io/proxy-body-size\": \"0\"}' | ${KUBECTL} replace -f -"
}

function check_osm_deployed() {
    TIME_TO_WAIT=300
    start_time="$(date -u +%s)"
    while true
    do
        pod_name=`sg ${KUBEGRP} -c "${KUBECTL} -n osm get pods | grep ui-k8s | grep -v operator" | awk '{print $1; exit}'`

        if [[ `sg ${KUBEGRP} -c "${KUBECTL} -n osm wait pod $pod_name --for condition=Ready"` ]]; then
            if [[ `sg ${KUBEGRP} -c "${KUBECTL} -n osm wait pod lcm-k8s-0 --for condition=Ready"` ]]; then
                break
            fi
        fi
        now="$(date -u +%s)"
        if [[ $(( now - start_time )) -gt $TIME_TO_WAIT ]];then
            echo "Timeout waiting for services to enter ready state"
            exit 1
        fi
        sleep 10
    done
}

function create_overlay() {
    sudo snap install jq
    sudo apt install python3-pip -y
    python3 -m pip install yq
    PATH=$PATH:$HOME/.local/bin  # make yq command available
    local HOME=/home/$USER
    local vca_user=$(cat $HOME/.local/share/juju/accounts.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME].user')
    local vca_password=$(cat $HOME/.local/share/juju/accounts.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME].password')
    local vca_host=$(cat $HOME/.local/share/juju/controllers.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME]["api-endpoints"][0]' --raw-output | cut -d ":" -f 1)
    local vca_port=$(cat $HOME/.local/share/juju/controllers.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME]["api-endpoints"][0]' --raw-output | cut -d ":" -f 2)
    local vca_pubkey=\"$(cat $HOME/.local/share/juju/ssh/juju_id_rsa.pub)\"
    local vca_cloud="lxd-cloud"
    # Get the VCA Certificate
    local vca_cacert=$(cat $HOME/.local/share/juju/controllers.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME]["ca-cert"]' --raw-output | base64 | tr -d \\n)

    # Calculate the default route of this machine
    local DEFAULT_IF=`ip route list match 0.0.0.0 | awk '{print $5}'`

    # Generate a new overlay.yaml, overriding any existing one
    cat << EOF > /tmp/vca-overlay.yaml
applications:
  lcm-k8s:
    options:
      vca_user: $vca_user
      vca_password: $vca_password
      vca_host: $vca_host
      vca_port: $vca_port
      vca_pubkey: $vca_pubkey
      vca_cacert: $vca_cacert
      vca_cloud: $vca_cloud
      vca_k8s_cloud: $K8S_CLOUD_NAME
  mon-k8s:
    options:
      vca_user: $vca_user
      vca_password: $vca_password
      vca_host: $vca_host
      vca_cacert: $vca_cacert
EOF
    mv /tmp/vca-overlay.yaml ~/.osm/
    OSM_VCA_HOST=$vca_host
}

function generate_images_overlay(){
    cat << EOF > /tmp/images-overlay.yaml
applications:
  lcm-k8s:
    options:
      image: opensourcemano/lcm:$TAG
  mon-k8s:
    options:
      image: opensourcemano/mon:$TAG
  ro-k8s:
    options:
      image: opensourcemano/ro:$TAG
  nbi-k8s:
    options:
      image: opensourcemano/nbi:$TAG
  pol-k8s:
    options:
      image: opensourcemano/pol:$TAG
  ui-k8s:
    options:
      image: opensourcemano/light-ui:$TAG
  pla:
    options:
      image: opensourcemano/pla:$TAG
  ng-ui:
    options:
      image: opensourcemano/ng-ui:$TAG

EOF
    mv /tmp/images-overlay.yaml $IMAGES_OVERLAY_FILE
}

function install_osmclient() {
    sudo snap install osmclient
    sudo snap alias osmclient.osm osm
}


function install_microstack() {
    sudo snap install microstack --classic --beta
    sudo microstack.init --auto
    wget https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img -P ~/.osm/
    microstack.openstack image create \
    --public \
    --disk-format qcow2 \
    --container-format bare \
    --file ~/.osm/ubuntu-16.04-server-cloudimg-amd64-disk1.img \
    ubuntu1604
    ssh-keygen -t rsa -N "" -f ~/.ssh/microstack
    microstack.openstack keypair create --public-key ~/.ssh/microstack.pub microstack
    export OSM_HOSTNAME=`juju status --format json | jq -rc '.applications."nbi-k8s".address'`
    osm vim-create --name microstack-site \
    --user admin \
    --password keystone \
    --auth_url http://10.20.20.1:5000/v3 \
    --tenant admin \
    --account_type openstack \
    --config='{security_groups: default,
        keypair: microstack,
        project_name: admin,
        user_domain_name: default,
        region_name: microstack,
        insecure: True,
        availability_zone: nova,
    version: 3}'
}

DEFAULT_IF=`ip route list match 0.0.0.0 | awk '{print $5}'`
DEFAULT_IP=`ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}'`

check_arguments $@
mkdir -p ~/.osm
install_snaps
bootstrap_k8s_lxd
deploy_charmed_osm
install_osmclient
if [ -v MICROSTACK ]; then
    install_microstack
fi

echo "Your installation is now complete, follow these steps for configuring the osmclient:"
echo
echo "1. Create the OSM_HOSTNAME environment variable with the NBI IP"
echo
echo "export OSM_HOSTNAME=nbi.$API_SERVER.xip.io:443"
echo
echo "2. Add the previous command to your .bashrc for other Shell sessions"
echo
echo "echo \"export OSM_HOSTNAME=nbi.$API_SERVER.xip.io:443\" >> ~/.bashrc"
echo
echo "DONE"
