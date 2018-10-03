#!/bin/sh

WAIT_TIME=60
NUM_SERVICES_WITH_HEALTH=3

while getopts "w:s:n:" o; do
    case "${o}" in
        w)
            WAIT_TIME=${OPTARG}
            ;;
        s)
            STACK_NAME=${OPTARG}
            ;;
        n)
            NUM_SERVICES_WITH_HEALTH=${OPTARG}
            ;;
    esac
done


time=0
step=1
while [ $time -le "$WAIT_TIME" ]; do
    if [ "$(docker ps | grep " ${STACK_NAME}_" | grep -i healthy | wc -l)" -ge "$NUM_SERVICES_WITH_HEALTH" ]; then
        exit 0
    fi

    sleep $step
    time=$((time+step))
done

echo "Not all Docker services are healthy"
docker ps | grep " ${STACK_NAME}_"

exit 1
