#!/bin/bash
#
# Peerplays node manager
# Released under GNU AGPL by Someguy123
# Modified by Tyler Fletcher

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOCKER_DIR="$DIR/dkr"
DATADIR="$DIR/data"
DOCKER_NAME="peerplays"

BOLD="$(tput bold)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
RESET="$(tput sgr0)"

# default. override in .env
PORTS="9777"

if [[ -f .env ]]; then
    source .env
fi

if [[ ! -f data/witness_node_data_dir/config.ini ]]; then
    echo "config.ini not found. copying example (seed)";
    cp data/witness_node_data_dir/config.ini.example data/witness_node_data_dir/config.ini
fi

IFS=","
DPORTS=()
for i in $PORTS; do
    if [[ $i != "" ]]; then
            DPORTS+=("-p0.0.0.0:$i:$i")
    fi
done

help() {
    echo "Usage: $0 COMMAND [DATA]"
    echo
    echo "Commands: "
    echo "    start - Starts Peerplays Container"
    echo "    replay - Starts Peerplays Container (In Replay Mode)"
    echo "    shm_size - Resizes /dev/shm to size given, e.g. ./run.sh shm_size 10G "
    echo "    stop - Stops The Peerplays Container"
    echo "    status - Show The Status Of The Peerplays Container"
    echo "    restart - Restarts The Peerplays Container"
    echo "    download_image - Downloads the latest docker image from Docker Hub (no compiling)"
    echo "    build - Builds The Peerplays Container (From Dockerfile)"
    echo "    build_and_start - Builds The Peerplays Container (From Dockerfile) And Starts The Container"
    echo "    logs - Show All Logs (Docker Logs and Peerplays Logs)"
    echo "    wallet - Open cli_wallet in the container"
    echo "    enter - Enter a bash session in the container"
    echo
    exit
}


build() {
    echo $GREEN"Building docker container"$RESET
    cd $DOCKER_DIR
    docker build -t peerplays .
}

download_image() {
    echo "Loading image from fletchertyler914/peerplays:latest"
    docker pull fletchertyler914/peerplays:latest
    echo "Tagging as peerplays"
    docker tag fletchertyler914/peerplays:latest peerplays
    echo "Latest Peerplays Docker Image Has Been Fetched."
    echo "Don't Forget To Configure Your Witness Node Details!"
}

seed_exists() {
    seedcount=$(docker ps -a -f name="^/"$DOCKER_NAME"$" | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return -1
    fi
}

seed_running() {
    seedcount=$(docker ps -f 'status=running' -f name=$DOCKER_NAME | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return -1
    fi
}

start() {
    echo $GREEN"Starting container..."$RESET
    seed_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} -v /dev/shm:/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t peerplays
    fi
}

replay() {
    echo "Removing old container"
    docker rm $DOCKER_NAME
    echo "Running peerplays with replay..."
    docker run ${DPORTS[@]} -v /dev/shm:/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t peerplays witness_node --replay
    echo "Started."
}

shm_size() {
    echo "Setting SHM to $1"
    mount -o remount,size=$1 /dev/shm
}

stop() {
    echo $RED"Stopping container..."$RESET
    docker stop $DOCKER_NAME
    docker rm $DOCKER_NAME
}

enter() {
    docker exec -it $DOCKER_NAME bash
}

wallet() {
    docker exec -it $DOCKER_NAME cli_wallet
}

logs() {
    echo $BLUE"DOCKER LOGS: "$RESET
    docker logs --tail=30 $DOCKER_NAME
    #echo $RED"INFO AND DEBUG LOGS: "$RESET
    #tail -n 30 $DATADIR/{info.log,debug.log}
}

status() {
    
    seed_exists
    if [[ $? == 0 ]]; then
        echo "Container exists?: "$GREEN"YES"$RESET
    else
        echo "Container exists?: "$RED"NO (!)"$RESET 
        echo "Container doesn't exist, thus it is NOT running. Run $0 build && $0 start"$RESET
        return
    fi

    seed_running
    if [[ $? == 0 ]]; then
        echo "Container running?: "$GREEN"YES"$RESET
    else
        echo "Container running?: "$RED"NO (!)"$RESET
        echo "Container isn't running. Start it with $0 start"$RESET
        return
    fi

}

if [ "$#" -lt 1 ]; then
    help
fi

case $1 in
    build)
        echo "You may want to use '$0 install' for a binary image instead, it's faster."
        build
        ;;
    download_image)
        download_image
        ;;
    start)
        start
        ;;
    replay)
        replay
        ;;
    shm_size)
        shm_size $2
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 5
        start
        ;;
    build_and_start)
        stop
        sleep 5
        build
        start
        ;;
    optimize)
        echo "Applying recommended dirty write settings..."
        optimize
        ;;
    status)
        status
        ;;
    wallet)
        wallet
        ;;
    enter)
        enter
        ;;
    logs)
        logs
        ;;
    *)
        echo "Invalid cmd"
        help
        ;;
esac
