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
function remove_iptables() {
    stack=$1
    if [ -z "$OSM_VCA_HOST" ]; then
        OSM_VCA_HOST=`sg lxd -c "juju show-controller controller"|grep api-endpoints|awk -F\' '{print $2}'|awk -F\: '{print $1}'`
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

remove_iptables
juju destroy-model osm --destroy-storage -y
juju destroy-model test --destroy-storage -y
sudo snap unalias osm
sudo snap remove osmclient
