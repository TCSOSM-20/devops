#!/bin/bash
export PATH=$PATH:/snap/bin
echo "PATH=$PATH"
juju status

git clone https://osm.etsi.org/gerrit/osm/vim-emu.git
git clone https://osm.etsi.org/gerrit/osm/devops.git
eval devops/installers/full_install_osm.sh --nolxd -y "$1"

cat >> ~/.bashrc <<-EOF
export OSM_HOSTNAME=127.0.0.1
export OSM_SOL005=True

EOF
