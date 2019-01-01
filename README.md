+Morpheus' CryptoNote helper script for Ubuntu 18.04

++A significant re-write and refinement of my original turtlecoin-docker-release script.

The *helper.sh* script needs a *config.sh* file to read its variables from.
Copy one of the included examples and edit it for your coin.

++++The helper script simplifies:
 - downloading, updating, compiling the source code
 - building/ updating the docker image
 - starting and stopping the daemon/miner docker container
 - monitoring the containerised daemon, including detection of network forks and restart of daemon

This script simplifies running seed/public nodes and/or CPU miners.

To use it, create a parent directory, to contain these scripts in /helper, the source in /coinname
and the stripped binaries which will be copied to the docker in /bin, like this:

coinparent
 |- helper
 |- coinname
 |- bin

To change this setup, edit the config.sh file RELA_PATH and OUT_DIR variables.

+++Usage
Run dockerprep.sh firstly to get the docker-ce package installed.  This is a basic script and if it fails
you'll have to figure it out for yourself. 9/10 it might work..

From GitHub to Docker:
*./helper {check|update|compile|strip|build|autoprep}*
('check' checks and optinally installs compile prerequisites
'autoprep' runs through all procedures)

++++Daemon Control:
*./helper {daemonstart|daemonstop|daemonrestart}*

++++Miner Control:
*./helper {minerstart|minerstop|minerrestart}*

++++Monitor:
*./helper monitor*