#!/bin/bash
#Written and copyright Morpheus (19morpheus80) [http://github.com/19morpheus80] under the GPL 3.0 License

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/config.sh"

if [ -z $GH_REPO ]; then
    echo "You must rename one of the examples to$T_BOLD config.sh$T_NORM and edit as required for your coin."
    exit 1
fi

get_docker_ip () {
    echo $(docker ps -q | xargs -n 1 docker inspect --format '{{ .NetworkSettings.IPAddress }} {{ .Name }}' | sed 's/ \// /' | awk "/$1/ { print \$1; }")
}

package_updater () {
    read -p "Would you like to run apt update before installing a package? (y/N): " U_INPUT
        if [[ "$U_INPUT" = "y" ]] || [[ "$U_INPUT" = "Y" ]]; then
            sudo apt-get update
        fi
    P_UPDATE="1"
}

package_installer () {
    if [ -z "$P_UPDATE" ]; then
        package_updater
    fi
    read -p "Would you like to install the pre-requisite $T_BOLD$1$T_NORM now? (Y/n): " U_INPUT
    if [[ ! "$U_INPUT" = "n" ]] || [[ ! "$U_INPUT" = "N" ]]; then
        echo "Installing $1"
        sudo apt-get install $1
    fi
}

check_pre_reqs () {
    for i in "${pReq[@]}"; do
        dpkg -s $i &> /dev/null
        if [ ! $? -eq 0 ]; then
            echo "Package $T_BOLD$i$T_NORM is not installed!"
            package_installer $i
        fi
    done
    for i in "${pReq[@]}"; do
        echo "find $T_BOLD$i$T_NORM"
        dpkg -s $i | grep Status
        if [ ! $? -eq 0 ]; then
            echo "$i has errorlevel not 0"
            CPR_RESULT="1"
        else
            CPR_RESULT="0"
        fi
    done
    if [ $CPR_RESULT -eq 0 ]; then
        echo "All dependencies are met"
    else
        echo "Not all dependencies are met"
        exit 1
    fi
    if [ $CONFIG_FIREWALL = "Yes" ]; then
        sudo ufw allow $P2P_PORT/tcp
        sudo ufw allow $RPC_PORT/tcp
    fi
}

compile () {
    local BUILD_PATH="$REPO_PATH/build"
    declare -i THREADS="$((`lscpu | grep 'CPU(s)' | head -1 | awk '{ print $2; }'`))"
    read -p "Compile $GH_REPO with how many threads? (default=$THREADS, 0=cancel) " U_INPUT
    if [ -z $U_INPUT ]; then
        U_INPUT="$THREADS"
    fi
    if [[ $U_INPUT -ge 1 ]] && [[ $U_INPUT -le $THREADS ]]; then
        THREADS="$U_INPUT"
    else
        echo "Cancelling compile"
        return 1
    fi
    pwd
    if [ ! -d "$BUILD_PATH" ]; then
        mkdir "$BUILD_PATH"
    else
        read -p "Build path already exists.  Erase before continuing? (Y/n): " U_INPUT
        if [[ ! $U_INPUT = "n" ]] && [[ ! $U_INPUT = "N" ]]; then
            rm -rf "$BUILD_PATH" && mkdir $_
        fi
    fi
      echo "Attempting compile with $THREADS threads."
    if (( $? < 1 )); then
        cd "$BUILD_PATH"
        cmake ..
        cd "$WORK_PATH"
    else
        return 1
    fi
    if (( $? < 1)); then
        cd "$BUILD_PATH"
        make -j$THREADS
        cd "$WORK_PATH"
    else
        return 1
    fi
    if (( $? > 0)); then
        echo "An error occured which stopped compilation."
        exit 1
    fi
}

update_source () {
    if [ ! -d "$REPO_PATH" ]; then
        read -p "Source path $GH_REPO not found.  Clone git now? (Y/n): " U_INPUT
        if [[ ! $U_INPUT = "n" ]] && [[ ! $U_INPUT = "N" ]]; then
            cd "$RELA_PATH"
            git clone --branch $GH_BRANCH $GH_URL$GH_REPO
        fi
    else
        read -p "Source path $GH_REPO found.  Update now? (Y/n): " U_INPUT
        if [[ ! $U_INPUT = "n" ]] && [[ ! $U_INPUT = "N" ]]; then
            cd "$REPO_PATH"
            git pull
        fi
    fi
    cd "$WORK_PATH"
}

strip_binaries () {
    local BUILDOUT_PATH=$(readlink -f "$REPO_PATH/build/src") #where the original binaries were put
    local CMAKELIST_PATH=$(readlink -f "$REPO_PATH/src/CMakeLists.txt") #to read the binary names from
    local DEXEC_PATH="$BUILDOUT_PATH/$D_EXEC" #check for the daemon executable. If it's not there we assume the compile failed
    if [ -e "$DEXEC_PATH" ]; then
        if [ -d "$BINDEST_PATH" ]; then
            read -p "Binary destination $BINDEST_PATH already exists! Continuing will overwrite existing binaries. Continue? (Y/n): " U_INPUT
            if [[ $U_INPUT = "n" ]] && [[ $U_INPUT = "N" ]]; then
                exit 1
            else
                echo "OK.."
            fi
        fi
        if [ ! -d "$BINDEST_PATH" ]; then
            mkdir $BINDEST_PATH
        fi
        #Get the list of binaries from the CMakeLists file
        for FN in `awk '/OUTPUT_NAME/ {print $5;}' $CMAKELIST_PATH | awk 'BEGIN { FS="\""; } {print $2;}'`
          do echo "Stripping $FN to $BINDEST_PATH/$FN"
          strip -o "$BINDEST_PATH/$FN" -s "$BUILDOUT_PATH/$FN"
        done
    else
        echo "Did not find daemon binary.  Did you compile the source code?"
    fi
}

write_dockerfile () {
    echo "#we don't want zipfiles or scripts included" > "$1/.dockerignore"
    echo "*/7z" >> "$1/.dockerignore"
    echo "*/zip" >> "$1/.dockerignore"
    echo "*/sh" >> "$1/.dockerignore"
    echo "*/ignore" >> "$1/.dockerignore"
    echo "FROM ubuntu" > "$1/Dockerfile"
    echo "RUN apt update && \\" >> "$1/Dockerfile"
    echo "    apt -y upgrade" >> "$1/Dockerfile"
    echo "ADD . /usr/bin" >> "$1/Dockerfile"
    if [ ! -z "$CHECKPOINTS_URL" ]; then
        echo "ADD '$CHECKPOINTS_URL' /root/checkpoints.csv" >> "$1/Dockerfile"
    fi
    echo "EXPOSE $P2P_PORT/tcp" >> "$1/Dockerfile"
    echo "EXPOSE $RPC_PORT/tcp" >> "$1/Dockerfile"
}

build_docker_image () {
    read -p "Build/update Docker image? (Y/n): " U_INPUT
    if [[ ! $U_INPUT = "n" ]] && [[ ! $U_INPUT = "N" ]]; then
        if [ -d $BINDEST_PATH ]; then
            write_dockerfile "$BINDEST_PATH"
            cd "$BINDEST_PATH"
            docker build -t $GH_REPO .
        else
            echo "Couldn't find $REPO_PATH"
        fi
        echo "Finished Updating"
    fi
    cd "$WORK_PATH"
}

print_miner_command () {
    local _message="$T_BOLD"
    _message+="Miner will start with:$T_NORM $MINER_COMMAND"
    echo "$_message"
}

print_daemon_commmand () {
    local _message="$T_BOLD"
    _message+="Daemon will start with:$T_NORM $DAEMON_COMMAND"
    echo $_message
}

miner_start () {
    echo "Starting Docker container as service.."
    DAEMON_IP=$(get_docker_ip $DOCK_DAEMON)

    eval $MINER_COMMAND
}

miner_stop () {
    echo "Stopping Docker.."
    docker stop $DOCK_MINER
    docker rm $DOCK_MINER
}

miner_restart () {
  docker restart $DOCK_MINER
}

daemon_start () {
    echo "Starting daemon in Docker container as service.."
    eval $DAEMON_COMMAND
}

daemon_stop () {
    echo "Stopping Daemon.."
    docker stop $DOCK_DAEMON
    docker rm $DOCK_DAEMON
}

daemon_restart () {
  echo "Restarting Daemon.."
  docker restart $DOCK_DAEMON
}

docker_monitor () {
    while [ $? -eq 0 ]; do
        DAEMON_IP=$(get_docker_ip $DOCK_DAEMON)
        if [ -z $DAEMON_IP ]; then
            echo "Daemon does not seem to be running!"
        else
            
            NODE_INFO=$(wget -qO- $DAEMON_IP:$RPC_PORT/getinfo | jq '{difficulty, hashrate, height, network_height, status, synced, incoming_connections_count, outgoing_connections_count}')
            MINER_IP=$(get_docker_ip $DOCK_MINER)
            if [ -z $MINER_IP ]; then
                _miner="Miner does not seem to be running"
            else
                _miner=$(docker logs --tail 10 $DOCK_MINER | grep "Mining" | tail -1)
            fi
            _difficulty=$(echo "$NODE_INFO" | grep difficulty | grep -o '[0-9]\+')
            _hashrate=$(echo "$NODE_INFO" | grep hashrate | grep -o '[0-9]\+')
            _height=$(echo "$NODE_INFO" | grep height | grep -o '[0-9]\+')
            _netheight=$(echo "$NODE_INFO" | grep network_height | grep -o '[0-9]\+')
            _heightdiff=$(awk "BEGIN {print $_netheight - $_height}")
            _incoming=$(echo "$NODE_INFO" | grep incoming_connections_count | grep -o '[0-9]\+')
            _outgoing=$(echo "$NODE_INFO" | grep outgoing_connections_count | grep -o '[0-9]\+')
            _synced=$(echo "$NODE_INFO" | grep synced | grep -o true)
            if [ ! -z $_synced ]; then
                _synced="Yes"
            fi
            clear
            echo "Monitoring $DOCK_DAEMON daemon running on $DAEMON_IP"
            echo "Difficulty:  $(numfmt --to=si --format='%.2f' $_difficulty)"
            echo "Hashrate:    $(numfmt --to=si --format='%.3f' $_hashrate)H/s"
            echo "Height:      $_netheight(+/-$_heightdiff)"
            echo "Conn.:       In:$_incoming/Out:$_outgoing"
            if [ ! -z $_synced ]; then
              echo "Synced:      $_synced"
            else
              echo "Syncing..."
            fi
            echo "$_miner"
            if [ $_restartcount -ge 1 ]; then
                echo "Restarted $_restartcount times"
            fi
            if [ ! -z $_synced  ] && [ $_heightdiff -gt $_allowsyncdiff ]; then
                echo "Out of sync - Restarting daemon!"
                let "_restartcount++"
                echo $_restartcount
                daemon_restart
            fi
        _tail5logs=$(docker logs --tail 5 $DOCK_DAEMON)
        echo "Daemon log: "
        echo ""
        echo "$_tail5logs"
        sleep 10
        fi
    done
}

show_docker_ips () {
    docker ps -q | xargs -n 1 docker inspect --format '{{ .NetworkSettings.IPAddress }} {{ .Name }}' | sed 's/ \// /'
}

reset_blockchain () {
    read -p "Delete blockchain storage and get your daemon running again? (y/N) " U_INPUT
    if [ $U_INPUT = "y" ] || [ $U_INPUT = "Y" ]; then
        miner_stop
        daemon_stop
				if [ ! -z $DATA_DIR ]; then
						echo "Type: rm -rf $DATA_DIR" #I'm chickening out of leaving this live
				else
						docker volume rm $S_NAME-data
            echo "Ready to rock"
				fi
    else
        echo "OK let's not do that then"
    fi
}

echo $"$_titlebanner"

case "$1" in
        show)
            show_docker_ips
            ;;
        check)
            check_pre_reqs
            ;;
        cmd)
            print_daemon_commmand
            echo " "
            print_miner_command
            ;;
        update)
            update_source
            ;;
        compile)
            compile
            ;;
        strip)
            strip_binaries
            ;;
        build)
            build_docker_image
            ;;
        autoprep)
            check_pre_reqs
            update_source
            compile
            strip_binaries
            build_docker_image
            ;;
        mstart)
            miner_start
            ;;         
        mstop)
            miner_stop
            ;;
        mrestart)
            miner_restart
            ;;
        dstart)
            daemon_start
            ;;         
        dstop)
            daemon_stop
            ;;
        drestart)
            daemon_restart
            ;;
        resetstorage)
            reset_blockchain
            ;;
        monitor)
            docker_monitor
            ;;
        about)
            echo "$_aboutbanner"
            ;;
         *)
            echo $"Prep   Usage: $0 {autoprep} || {check|update|compile|strip|build}"
            echo $"Daemon Usage: $0 {dstart|dstop|drestart|resetstorage}"
            echo $"Miner  Usage: $0 {mstart|mstop|mrestart}"
            echo $"Info.  Usage: $0 {cmd|show|monitor|about}"
            echo ""
            echo $"General guide: If you're seeing this, a config file is loaded.  Have you checked it?"
            echo $"Autoprep builds the docker image with binaries using subsequent commands (use this)."
            echo $"The daemon and miner commands are self explanatory. Restart commands only restart the docker."
            echo $"(good if your daemon looses sync).  If you change the configuration, stop then start manually."
            exit 1
esac
