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
-v, --version; Set presto version
-i, --incremental; Allow incremetal build
-c, --clean; Clean artifacts directory with downloaded RPM and CLI
" | column -t -s ";"
}

INCREMETAL=false
CLEAN=false

options=$(getopt -o v:ic --long version:,incremental,cleanup -n 'parse-options' -- "$@")

if [ $? != 0 ]; then
  echo "Failed parsing options." >&2
  exit 1
fi

while true; do
  case "$1" in
    -v | --version ) PRESTO_VERSION=$2; shift 2;;
    -i | --incremental) INCREMETAL=true; shift ;;
    -c | --cleanup) CLEAN=true; shift ;;
    -- ) shift; break ;;
    "" ) break ;;
    * ) echo "Unknown option provided ${1}"; usage; exit 1; ;;
  esac
done

if [ -z "${PRESTO_VERSION}" ]; then
  echo "-v/--version option is missing"
  usage
  exit 1
fi

set -xeuo pipefail

ARTIFACTS_DIR="installdir"

PRESTO_RPM_BASENAME="presto-server-rpm-${PRESTO_VERSION}.x86_64.rpm"
PRESTO_CLI_BASENAME="presto-cli-${PRESTO_VERSION}-executable.jar"

DIST_LOCATION="$(${ARTIFACTS_DIR}/find-dist-location.sh "" "${PRESTO_VERSION}")"
PRESTO_RPM="${DIST_LOCATION}/${PRESTO_RPM_BASENAME}"
PRESTO_CLI="${DIST_LOCATION}/${PRESTO_CLI_BASENAME}"


function cleanup {
  rm -f "${ARTIFACTS_DIR}/${PRESTO_RPM_BASENAME}"
  rm -f "${ARTIFACTS_DIR}/${PRESTO_CLI_BASENAME}"
}

if [ "$CLEAN" = true ] ; then
    trap cleanup EXIT
fi

if [ ! -f "${ARTIFACTS_DIR}/${PRESTO_RPM_BASENAME}" ]; then
    curl -fsSL "${PRESTO_RPM}" -o "${ARTIFACTS_DIR}/${PRESTO_RPM_BASENAME}"
fi

if [ ! -f "${ARTIFACTS_DIR}/${PRESTO_CLI_BASENAME}" ]; then
    curl -fsSL "${PRESTO_CLI}" -o "${ARTIFACTS_DIR}/${PRESTO_CLI_BASENAME}"
fi

IMAGE_NAME=starburstdata/presto:${PRESTO_VERSION}

if [ "${INCREMETAL}" = true ] && [[ $(docker image list -q ${IMAGE_NAME}) ]]; then
  echo "Running incremetal build..."
  docker build . \
    --build-arg "presto_rpm=${PRESTO_RPM_BASENAME}" \
    --build-arg "presto_cli=${PRESTO_CLI_BASENAME}" \
    --build-arg "artifacts_dir=${ARTIFACTS_DIR}" \
    --build-arg "BASE_IMAGE=${IMAGE_NAME}" \
    -t "${IMAGE_NAME}" \
    -f incremental.Dockerfile \
    --squash --rm
else
  docker build . \
    --build-arg "presto_rpm=${PRESTO_RPM_BASENAME}" \
    --build-arg "presto_cli=${PRESTO_CLI_BASENAME}" \
    --build-arg "artifacts_dir=${ARTIFACTS_DIR}" \
    -t "${IMAGE_NAME}" \
    --squash --rm
fi
