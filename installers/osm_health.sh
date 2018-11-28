#!/bin/sh

WAIT_TIME=180  # LCM healthcheck needs 140 senconds
SERVICES_WITH_HEALTH="nbi ro zookeeper lcm mon"
NUM_SERVICES_WITH_HEALTH=$(echo $SERVICES_WITH_HEALTH | wc -w)
WAIT_FINAL=30

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
step=2
while [ $time -le "$WAIT_TIME" ]; do
    if [ "$(docker ps | grep " ${STACK_NAME}_" | grep -i healthy | wc -l)" -ge "$NUM_SERVICES_WITH_HEALTH" ]; then
        # all dockers are healthy now.
        # final sleep is needed until more health checks are added to validate system is ready to handle requests
        sleep $WAIT_FINAL
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

