#!/bin/bash

# Gets the command name without path
function cmd()
{
  basename $0
}

function usage()
{
  echo "\
`cmd` [OPTIONS...]

  This utility is used to build and push the starburstdata Presto and UBI
  images.

-p, --do-not-push  Flag preventing the newly built Docker image from being pushed
                   to the Docker registry. This flag acts on both
                   the Presto image and UBI. By default newly built images are
                   pushed.

-l, --latest       Flag indicating if the Presto image should be pushed to the
                   latest tag. Defaults to false.

-u, --ubi          Flag indiciating if the Universal Base Image of Presto should
                   be built. Defaults to false.
"
}

PUSH=true
LATEST=false
UBI=false
# Edit this variable directly to build and release another version
PRESTO_VERSION="323-e.3"

options=$(getopt -o plu --long do-not-push,latest,ubi -n 'parse-options' -- "$@")

if [ $? != 0 ]; then
  echo "Failed parsing options." >&2
  exit 1
fi

while true; do
  case "$1" in
    -p | --do-not-push) PUSH=false; shift ;;
    -l | --latest) LATEST=true; shift ;;
    -u | --ubi) UBI=true; shift ;;
    -- ) shift; break ;;
    "" ) break ;;
    * ) echo "Unknown option provided ${1}"; usage; exit 1; ;;
  esac
done

set -xeuo pipefail

if [ "$PUSH" = true ] ; then
    docker login --username $JENKINS_USERNAME --password $JENKINS_PASSWORD
fi

./build-image.sh --version $PRESTO_VERSION 

if [ "$PUSH" = true ] ; then
    docker push starburstdata/presto:$PRESTO_VERSION
fi

if [ "$LATEST" = true ] ; then
  docker tag starburstdata/presto:$PRESTO_VERSION starburstdata/presto:latest
  docker push starburstdata/presto:latest
fi

if [ "$UBI" = true ] ; then
  virtualenv -p python3 .venv
  source .venv/bin/activate
  pip3 install awscli --upgrade
  aws ecr get-login --no-include-email --region us-east-2 | bash
  DOCKER_REGISTRY="200442618260.dkr.ecr.us-east-2.amazonaws.com/k8s"
  docker build . -t $DOCKER_REGISTRY/starburstdata/presto:${TAG}-ubi8.1 --build-arg base_image="$DOCKER_REGISTRY/starburstdata/ubi8-python2:1"
  docker push $DOCKER_REGISTRY/starburstdata/presto:${TAG}-ubi8.1
fi
