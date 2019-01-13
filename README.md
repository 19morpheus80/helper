# Morpheus' CryptoNode helper script for Ubuntu 18.04

## The helper script simplifies:
 - downloading, updating, compiling the source code
 - building/ updating the docker image
 - starting and stopping the daemon/miner docker container
 - monitoring the containerised daemon, including detection of network forks and restart of daemon

This script simplifies running seed/public nodes and/or CPU miners.

Use it like this:

```
mkdir coin && cd $_
git clone https://19morpehus80/helper
cd helper
./dockerprep.sh
cp config.turtlecoin.example config.sh
nano config.sh

./helper.sh
Morpheus'
┌─┐┬─┐┬ ┬┌─┐┌┬┐┌─┐┌┐┌┌─┐┌┬┐┌─┐  ┬ ┬┌─┐┬  ┌─┐┌─┐┬─┐
│  ├┬┘└┬┘├─┘ │ │ │││││ │ ││├┤   ├─┤├┤ │  ├─┘├┤ ├┬┘
└─┘┴└─ ┴ ┴   ┴ └─┘┘└┘└─┘─┴┘└─┘  ┴ ┴└─┘┴─┘┴  └─┘┴└─

Prep   Usage: ./helper.sh {autoprep} || {check|update|compile|strip|build}
Daemon Usage: ./helper.sh {dstart|dstop|drestart}
Miner  Usage: ./helper.sh {mstart|mstop|mrestart}
Info.  Usage: ./helper.sh {cmd|show|monitor|about}

./helper.sh autoprep
... press enter a few times and wait for compile ..
./helper.sh dstart
./helper.sh monitor
... wait for sync ... ctrl+c
./helper.sh mstart (if you want to mine as well)

```
