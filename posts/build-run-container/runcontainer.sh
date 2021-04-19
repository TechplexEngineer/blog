#!/bin/bash

set -euo pipefail
# set -x
#
# runcontainer.sh - Script which will run a build container for a workspace
#
# Example Use: ./runcontainer.sh ubuntu:latest
#
# This script start a container from the supplied image and bind mounts
# the current working directory into the container at the same system path.
# This allows for the container to be used to compile other workspaces.
#
# This script and its corresponding Dockerfile (dockerfile.runcontainer)
# MUST be found together in the same directory, otherwise this script will
# not find the necessary Dockerfile to create the build images.
#
# This has been tested on Ubuntu and Fedora using docker-ce from
# https://www.docker.com.  The native Ubuntu docker.io and Fedora docker*
# packages do not support the features necessary to create the build images
# (specifically, allowing for an ARG statement to be the first line of the
# Dockerfile instead of a FROM statement).  Please follow the instructions on
# https://www.docker.com to install the docker-ce packages for your
# distribution.
#
# Known issue: The docker installation MUST be configured to allow normal
# users to run docker commands so that the correct UID/GID/USERNAME are
# available to the script.  The script will not permit execution as the
# root user.
#
if [ "$(id -u)" = "0" ]; then
    echo "This script cannot be run as root.  Please try again from an"
    echo "unprivileged account."
    exit 1
fi

programName=$(basename "$0")

function usage() {
    echo "Usage: $programName IMAGE [CODE_DIR]"
    echo ""
    echo "$programName runs a container with IMAGE in CODE_DIR (or PWD if CODE DIR is undefined) "
}

numArgs=$#
if [[ $numArgs -ne 1 ]] \
        && [[ $numArgs -ne 2 ]] \
        || [[ "$1" == "-h" ]]; then
    usage
    exit 1
fi

script=$(readlink -f "$0")
scriptdir=${script%/*}

image="$1"
if [[ -z "$image" ]]; then
    usage
    exit 1
fi
volume_path="${PWD}"
if [[ -z "$1" ]]; then
    volume_path="$2"
fi


dockerfile="${scriptdir}/dockerfile.runcontainer"
if [ ! -f "${dockerfile}" ]; then
    echo "Cannot find ${dockerfile}."
    echo "Unable to continue."
    echo
    exit 1
fi

# Prints a warning message
function warn()
{
	if [ "$1" ]
	then
		echo -e "\e[31mWARN:\e[0m $1" >&2
	fi
}

if [[ "$image" != *":"* ]]; then
	warn "Image version not specified, assuming 'latest'"
	image="${image}:latest"
	echo "    using: ${image}"
fi

# strip off any namespaces eg. "username/" or "regurl/"
nameVer="${image##*/}"
# strip off the version, leaving just container name
containerName="${nameVer%%:*}"

imagever=${image##*:}
uid=$(id -u)
gid=$(id -g)
username=$(id -un)
imagename=${username}-${containerName}
tag=${imagename}:${imagever}
hostname=$(echo "${tag}" | tr -- . -)

echo "Checking to see if ${tag} exists"
if ! docker image inspect "${tag}" &> /dev/null; then
    echo "Creating container ${tag} from ${image} for user ${username}..."

    if docker build --build-arg IMAGE="${image}" \
        --build-arg UID="${uid}" \
        --build-arg GID="${gid}" \
        --build-arg UNAME="${username}" \
        -t "${tag}" - < "${dockerfile}"
    then
        echo "Done creating container image ${tag}."
    else
        echo "Error creating container image ${tag}!"
        echo "See previous output for error reason."
        exit 1
    fi
fi

name=$(mktemp -u "${imagename}-XXX")
echo "Starting container ${name} based on image ${tag}"
docker run -it \
    -v "${volume_path}:${volume_path}" \
    -w "${PWD}" \
    --rm \
    --hostname "${hostname}" \
    --name "${name}" "${tag}"

exit 0
