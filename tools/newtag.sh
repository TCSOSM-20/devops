#!/bin/bash
if [ $# -ne 5 ]; then
    echo "Usage $0 <repo> <branch> <tag> <user> <release_name>"
    echo "Example: $0 all master v4.0.2 garciadeblas FOUR"
    echo "Example: $0 devops v5.0 v5.0.3 marchettim FIVE"
    exit 1
fi

BRANCH="$2"
TAG="$3"
USER="$4"
RELEASE_NAME="$5"
tag_header="OSM Release $RELEASE_NAME:"
tag_message="$tag_header version $TAG"

modules="common devops IM LCM LW-UI MON N2VC NBI openvim osmclient RO vim-emu POL"
list=""
for i in $modules; do
    if [ "$1" == "$i" -o "$1" == "all" ]; then
        list="$1"
        break
    fi
done

[ "$1" == "all" ] && list=$modules

if [ -z "$list" ]; then
    echo "Repo must be one of these: $modules all"
    exit 1
fi

for i in $list; do
    echo $i
    if [ ! -d $i ]; then
        git clone ssh://$USER@osm.etsi.org:29418/osm/$i
    fi
    git -C $i checkout $BRANCH
    git -C $i pull --rebase
    git -C $i tag -a $TAG -m"$tag_message"
    git -C $i push origin $TAG --follow-tags
    sleep 2
done

exit 0
