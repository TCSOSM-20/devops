#!/bin/sh
#
#   Copyright 2020 ETSI
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

RELEASE="ReleaseEIGHT-daily"
REPOSITORY_KEY="OSM%20ETSI%20Release%20Key.gpg"
REPOSITORY="testing"
REPOSITORY_BASE="http://osm-download.etsi.org/repository/osm/debian"
DEBUG=

while getopts ":r:k:u:R:b:-:dm:p:" o; do
    case "${o}" in
        r)
            REPOSITORY=${OPTARG}
            ;;
        R)
            RELEASE=${OPTARG}
            ;;
        k)
            REPOSITORY_KEY=${OPTARG}
            ;;
        u)
            REPOSITORY_BASE=${OPTARG}
            ;;
        d)
            DEBUG=y
            ;;
        p)
            PACKAGE_NAME=${OPTARG}
            ;;
        m)
            MDG=${OPTARG}
            ;;
        -)
            ;;
    esac
done

if [ -z "$MDG" ]; then
    echo "missing MDG"
fi

[ -z "$PACKAGE_NAME" ] && PACKAGE_NAME=$MDG

if [ -n "$DEBUG" ]; then
    echo curl $REPOSITORY_BASE/$RELEASE/dists/$REPOSITORY/$MDG/binary-amd64/Packages
fi

curl $REPOSITORY_BASE/$RELEASE/dists/$REPOSITORY/$MDG/binary-amd64/Packages 2>/dev/null | awk -v pkg=$PACKAGE_NAME '{
    if ( /Package:/ && match($2,sprintf("%s$",tolower(pkg)) ) ) {
        package=1;
    } else if (package==1 && match($1,"Version:")) { 
        package=0; 
        printf("%s\n", $2);
    }
}' | head -1
