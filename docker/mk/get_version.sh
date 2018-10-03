#!/bin/sh

RELEASE="ReleaseFOUR-daily"
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
