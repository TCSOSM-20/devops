#!/bin/sh

WAIT_TIME=60
NUM_SERVICES_WITH_HEALTH=3
SERVICES_WITH_HEALTH="nbi ro kafka"

while getopts "w:s:n:c:" o; do
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
        c)
            SERVICES_WITH_HEALTH="${OPTARG}"
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

for S_WITH_HEALTH in $SERVICES_WITH_HEALTH ; do
    docker ps | grep " ${STACK_NAME}_" | grep -i healthy | grep -q "_${S_WITH_HEALTH}."  && continue
    echo
    echo BEGIN LOGS of container ${S_WITH_HEALTH} not healthy
    docker service logs ${STACK_NAME}_${S_WITH_HEALTH} 2>&1 | tail -n 100
    echo END LOGS of container ${S_WITH_HEALTH} not healthy
    echo
done

exit 1
