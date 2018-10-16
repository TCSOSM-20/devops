#!/bin/bash
export PATH=$PATH:/snap/bin
echo "PATH=$PATH"
juju status

wget https://osm-download.etsi.org/ftp/osm-4.0-four/install_osm.sh
chmod +x install_osm.sh
./install_osm.sh --nolxd -y

cat >> ~/.bashrc <<-EOF
export OSM_HOSTNAME=127.0.0.1
export OSM_SOL005=True

EOF
