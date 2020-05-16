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
IMAGES_OVERLAY_FILE=~/.osm/images-overlay.yaml
function check_arguments(){
    while [ $# -gt 0 ] ; do
        case $1 in
            --bundle) BUNDLE="$2" ;;
            --kubeconfig) KUBECFG="$2" ;;
            --controller) CONTROLLER="$2" ;;
            --lxd-cloud) LXD_CLOUD="$2" ;;
            --lxd-credentials) LXD_CREDENTIALS="$2" ;;
            --microstack) MICROSTACK=y ;;
            --tag) TAG="$2" ;;
        esac
        shift
    done

    # echo $BUNDLE $KUBECONFIG $LXDENDPOINT
}
function install_snaps(){
    sudo snap install juju --classic
    [ ! -v KUBECFG ] && sudo snap install microk8s --classic && sudo usermod -a -G microk8s ubuntu && mkdir -p ~/.kube && sudo chown -f -R `whoami` ~/.kube
}

function bootstrap_k8s_lxd(){
    [ -v CONTROLLER ] && ADD_K8S_OPTS="--controller ${CONTROLLER}" && CONTROLLER_NAME=$CONTROLLER
    [ ! -v CONTROLLER ] && ADD_K8S_OPTS="--client" && BOOTSTRAP_NEEDED="yes" && CONTROLLER_NAME="controller"

    if [ -v KUBECFG ]; then
        cat $KUBECFG | juju add-k8s $K8S_CLOUD_NAME $ADD_K8S_OPTS
        [ -v BOOTSTRAP_NEEDED ] && juju bootstrap $K8S_CLOUD_NAME $CONTROLLER_NAME
    else
        sg microk8s -c "microk8s.enable storage dns"

        [ ! -v BOOTSTRAP_NEEDED ] && sg microk8s -c "microk8s.config" | juju add-k8s $K8S_CLOUD_NAME $ADD_K8S_OPTS
        [ -v BOOTSTRAP_NEEDED ] && sg microk8s -c "juju bootstrap microk8s $CONTROLLER_NAME" && K8S_CLOUD_NAME=microk8s
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
    juju add-model test lxd-cloud || true
}

function deploy_charmed_osm(){
    create_overlay
    echo "Creating OSM model"
    if [ -v KUBECFG ]; then
        juju add-model osm $K8S_CLOUD_NAME
    else
        sg microk8s -c "juju add-model osm $K8S_CLOUD_NAME"
    fi
    echo "Deploying OSM with charms"
    # echo $BUNDLE
    if [ -v BUNDLE ]; then
        juju deploy $BUNDLE --overlay ~/.osm/vca-overlay.yaml
    else
        images_overlay=""
        [ -v TAG ] && generate_images_overlay && images_overlay="--overlay $IMAGES_OVERLAY_FILE"
        juju deploy osm --overlay ~/.osm/vca-overlay.yaml $images_overlay
    fi
    echo "Waiting for deployment to finish..."
    check_osm_deployed &> /dev/null
    echo "OSM with charms deployed"
    sg microk8s -c "microk8s.enable ingress"
    juju config ui-k8s juju-external-hostname=osm.$DEFAULT_IP.xip.io
    juju expose ui-k8s
}

function check_osm_deployed() {
    while true
    do
        pod_name=`sg microk8s -c "microk8s.kubectl -n osm get pods | grep ui-k8s | grep -v operator" | awk '{print $1}'`
        if [[ `sg microk8s -c "microk8s.kubectl -n osm wait pod $pod_name --for condition=Ready"` ]]; then
            if [[ `sg microk8s -c "microk8s.kubectl -n osm wait pod lcm-k8s-0 --for condition=Ready"` ]]; then
                break
            fi
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
    local vca_host=$(cat $HOME/.local/share/juju/controllers.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME]["api-endpoints"][0]' | cut -d ":" -f 1 | cut -d "\"" -f 2)
    local vca_port=$(cat $HOME/.local/share/juju/controllers.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME]["api-endpoints"][0]' | cut -d ":" -f 2 | cut -d "\"" -f 1)
    local vca_pubkey=\"$(cat $HOME/.local/share/juju/ssh/juju_id_rsa.pub)\"
    local vca_cloud="lxd-cloud"
    # Get the VCA Certificate
    local vca_cacert=$(cat $HOME/.local/share/juju/controllers.yaml | yq --arg CONTROLLER_NAME $CONTROLLER_NAME '.controllers[$CONTROLLER_NAME]["ca-cert"]' | base64 | tr -d \\n)

    # Calculate the default route of this machine
    local DEFAULT_IF=`route -n |awk '$1~/^0.0.0.0/ {print $8}'`
    local vca_apiproxy=`ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}'`

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
      vca_apiproxy: $vca_apiproxy
      vca_cloud: $vca_cloud
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

EOF
    mv /tmp/images-overlay.yaml $IMAGES_OVERLAY_FILE
}

function install_osmclient() {
    sudo snap install osmclient
    sudo snap alias osmclient.osm osm
}

function create_iptables() {
    check_install_iptables_persistent

    if ! sudo iptables -t nat -C PREROUTING -p tcp -m tcp -d $DEFAULT_IP --dport 17070 -j DNAT --to-destination $OSM_VCA_HOST; then
        sudo iptables -t nat -A PREROUTING -p tcp -m tcp -d $DEFAULT_IP --dport 17070 -j DNAT --to-destination $OSM_VCA_HOST
        sudo netfilter-persistent save
    fi
}

function check_install_iptables_persistent(){
    echo -e "\nChecking required packages: iptables-persistent"
    if ! dpkg -l iptables-persistent &>/dev/null; then
        echo -e "    Not installed.\nInstalling iptables-persistent requires root privileges"
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
        sudo apt-get -yq install iptables-persistent
    fi
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
    export OSM_HOSTNAME=`juju status --format yaml | yq r - applications.nbi-k8s.address`
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

DEFAULT_IF=`route -n |awk '$1~/^0.0.0.0/ {print $8}'`
DEFAULT_IP=`ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}'`

check_arguments $@
mkdir -p ~/.osm
install_snaps
bootstrap_k8s_lxd
deploy_charmed_osm
[ ! -v CONTROLLER ] && create_iptables
install_osmclient
if [ -v MICROSTACK ]; then
    install_microstack
fi
