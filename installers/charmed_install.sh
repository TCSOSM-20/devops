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
function check_arguments(){
    while [ $# -gt 0 ] ; do
      case $1 in
        --bundle) BUNDLE="$2" ;;
        --kubeconfig) KUBECFG="$2" ;;
        --lxd-endpoint) LXDENDPOINT="$2" ;;
        --lxd-cert) LXDCERT="$2" ;;
	--microstack) MICROSTACK=y
      esac
      shift
    done

    echo $BUNDLE $KUBECONFIG $LXDENDPOINT
}
function install_snaps(){
    sudo snap install juju --classic
    if [ -z "$KUBECFG" ]; then sudo snap install microk8s --classic; fi
}

function bootstrap_k8s_lxd(){
    if [ -n "$KUBECFG" ]; then
        echo "Using specified K8s"
        cat $KUBECFG | juju add-k8s k8s-cluster --client
        juju bootstrap k8s-cluster controller
    else
        sudo microk8s.enable storage dns
        sudo usermod -a -G microk8s ubuntu
        sg microk8s -c "juju bootstrap microk8s controller"
    fi

    if [ -n "$LXDENDPOINT" ]; then
        if [ -n "$LXDCERT" ]; then

            local server_cert=`cat $LXDCERT | sed 's/^/        /'`
        else
            echo "The installer needs the LXD server certificate if the LXD is external"
            exit 1
        fi
    else
        LXDENDPOINT=$DEFAULT_IP
        lxd init --auto --network-address $LXDENDPOINT
        lxc network set lxdbr0 ipv6.address none

        local server_cert=`cat /var/lib/lxd/server.crt | sed 's/^/        /'`
    fi

    sudo cat << EOF > ~/.osm/lxd-cloud.yaml
clouds:
  lxd-cloud:
    type: lxd
    auth-types: [certificate]
    endpoint: "https://$LXDENDPOINT:8443"
    config:
      ssl-hostname-verification: false
EOF
    openssl req -nodes -new -x509 -keyout ~/.osm/private.key -out ~/.osm/publickey.crt -days 365 -subj "/C=FR/ST=Nice/L=Nice/O=ETSI/OU=OSM/CN=osm.etsi.org"


    local client_cert=`cat ~/.osm/publickey.crt | sed 's/^/        /'`
    local client_key=`cat ~/.osm/private.key | sed 's/^/        /'`

    sudo cat << EOF > ~/.osm/lxd-credentials.yaml
credentials:
  lxd-cloud:
    admin:
      auth-type: certificate
      server-cert: |
$server_cert
      client-cert: |
$client_cert
      client-key: |
$client_key
EOF

   lxc config trust add local: ~/.osm/publickey.crt
   juju add-cloud -c controller lxd-cloud ~/.osm/lxd-cloud.yaml --force
   juju add-credential -c controller lxd-cloud -f ~/.osm/lxd-credentials.yaml
   juju add-model test lxd-cloud

}

function deploy_charmed_osm(){
    create_overlay
    echo "Creating OSM model"
    if [ -n "$KUBECFG" ]; then
        juju add-model osm-on-k8s k8s-cluster
    else
        sg microk8s -c "juju add-model osm-on-k8s microk8s"
    fi
    echo "Deploying OSM with charms"
    echo $BUNDLE
    if [ -n "$BUNDLE" ]; then
        juju deploy $BUNDLE --overlay ~/.osm/vca-overlay.yaml
    else
        juju deploy osm --overlay ~/.osm/vca-overlay.yaml
    fi
    echo "Waiting for deployment to finish..."
    check_osm_deployed &> /dev/null
    echo "OSM with charms deployed"
    sudo microk8s.enable ingress
    juju config ui-k8s juju-external-hostname=osm.$DEFAULT_IP.xip.io
    juju expose ui-k8s
}

function check_osm_deployed() {
    while true
    do
        pod_name=`sg microk8s -c "microk8s.kubectl -n osm-on-k8s get pods | grep ui-k8s | grep -v operator" | awk '{print $1}'
`

        if [[ `sg microk8s -c "microk8s.kubectl -n osm-on-k8s wait pod $pod_name --for condition=Ready"` ]]; then
             if [[ `sg microk8s -c "microk8s.kubectl -n osm-on-k8s wait pod lcm-k8s-0 --for condition=Ready"` ]]; then
                break
            fi
        fi
        sleep 10
    done
}

function create_overlay() {
    sudo snap install yq

    local YQ="$SNAP/bin/yq"
    local HOME=/home/$USER
    local vca_user=$(cat $HOME/.local/share/juju/accounts.yaml | yq  r - controllers.controller.user)
    local vca_password=$(cat $HOME/.local/share/juju/accounts.yaml | yq  r - controllers.controller.password)
    local vca_host=$(cat $HOME/.local/share/juju/controllers.yaml | yq  r - controllers.controller.api-endpoints[0] | cut -d ":" -f 1)
    local vca_port=$(cat $HOME/.local/share/juju/controllers.yaml | yq  r - controllers.controller.api-endpoints[0] | cut -d ":" -f 2)
    local vca_pubkey=\"$(cat $HOME/.local/share/juju/ssh/juju_id_rsa.pub)\"
    local vca_cloud="lxd-cloud"
    # Get the VCA Certificate
    local vca_cacert=$(cat $HOME/.local/share/juju/controllers.yaml | yq  r - controllers.controller.ca-cert | base64 | tr -d \\n)

    # Calculate the default route of this machine
    local DEFAULT_IF=`route -n |awk '$1~/^0.0.0.0/ {print $8}'`
    local vca_apiproxy=`ip -o -4 a |grep ${DEFAULT_IF}|awk '{split($4,a,"/"); print a[1]}'`

    # Generate a new overlay.yaml, overriding any existing one
    sudo cat << EOF > /tmp/vca-overlay.yaml
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
   sudo cp /tmp/vca-overlay.yaml ~/.osm/
   OSM_VCA_HOST=$vca_host
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
mkdir ~/.osm
install_snaps
bootstrap_k8s_lxd
deploy_charmed_osm
create_iptables
install_osmclient
if [ -n "$MICROSTACK" ]; then
    install_microstack
fi
