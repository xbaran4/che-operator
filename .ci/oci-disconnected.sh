#!/bin/bash
#
# Copyright (c) 2012-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# exit immediately when a command fails
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail
# error on unset variables
set -u

export OPERATOR_REPO=$(dirname $(dirname $(readlink -f "$0")));
source "${OPERATOR_REPO}"/.github/bin/common.sh
source "${OPERATOR_REPO}"/.github/bin/oauth-provision.sh

# Define Disconnected tests environment
export INTERNAL_REGISTRY_URL=${INTERNAL_REGISTRY_URL-"UNDEFINED"}
export INTERNAL_REG_USERNAME=${INTERNAL_REG_USERNAME-"UNDEFINED"}
export INTERNAL_REG_PASS="${INTERNAL_REG_PASS-"UNDEFINED"}"
export SLACK_TOKEN="${SLACK_TOKEN-"UNDEFINED"}"
export WORKSPACE="${WORKSPACE-"UNDEFINED"}"
export REG_CREDS=${XDG_RUNTIME_DIR}/containers/auth.json
export ORGANIZATION="eclipse"
export TAG_NIGHTLY="nightly"

#Stop execution on any error
trap "catchDisconnectedJenkinsFinish" EXIT SIGINT

# Catch an error after existing from jenkins Workspace
function catchDisconnectedJenkinsFinish() {
    EXIT_CODE=$?

    if [ "$EXIT_CODE" != "0" ]; then
      export JOB_RESULT=":alert-siren: Failed :alert-siren:"
    else
      export JOB_RESULT=":tada: Success :tada:"
    fi

    mkdir -p ${WORKSPACE}/artifacts
    chectl server:logs --directory=${WORKSPACE}/artifacts

    echo "[INFO] Please check Jenkins Artifacts-> ${BUILD_URL}"
    /bin/bash "${OPERATOR_REPO}"/.github/bin/slack.sh

    exit $EXIT_CODE
}

# Check if all necessary environment for disconnected test are defined
if [[ "$WORKSPACE" == "UNDEFINED" ]]; then
    echo "[ERROR] Jenkins Workspace env is not defined."
    exit 1
fi

if [[ "$SLACK_TOKEN" == "UNDEFINED" ]]; then
    echo "[ERROR] Internal registry credentials environment is not defined."
    exit 1
fi

if [[ "$REG_CREDS" == "UNDEFINED" ]]; then
    echo "[ERROR] Internal registry credentials environment is not defined."
    exit 1
fi

if [[ "$INTERNAL_REGISTRY_URL" == "UNDEFINED" ]]; then
    echo "[ERROR] Internal registry url environment is not defined."
    exit 1
fi

if [[ "$INTERNAL_REG_USERNAME" == "UNDEFINED" ]]; then
    echo "[ERROR] Internal registry username environment is not defined."
    exit 1
fi

if [[ "$INTERNAL_REG_PASS" == "UNDEFINED" ]]; then
    echo "[ERROR] Internal registry password environment is not defined."
    exit 1
fi

# Login to internal registry using podman
podman login -u "${INTERNAL_REG_USERNAME}" -p "${INTERNAL_REG_PASS}" --tls-verify=false ${INTERNAL_REGISTRY_URL} --authfile=${REG_CREDS}

# Get the ocp domain for che custom resources
export DOMAIN=$(oc get dns cluster -o json | jq .spec.baseDomain | sed -e 's/^"//' -e 's/"$//')

cat >/tmp/che-cr-patch.yaml <<EOL
spec:
  auth:
    updateAdminPassword: false
  server:
    airGapContainerRegistryHostname: $INTERNAL_REGISTRY_URL
    airGapContainerRegistryOrganization: 'eclipse'
    nonProxyHosts: oauth-openshift.apps.$DOMAIN
EOL

# Start a golang workspace
initDefaults
provisionOpenShiftOAuthUser

# Deploy Eclipse Che
chectl server:deploy --telemetry=off --k8spodwaittimeout=1800000 --che-operator-cr-patch-yaml=/tmp/che-cr-patch.yaml --che-operator-image=${INTERNAL_REGISTRY_URL}/eclipse/che-operator:nightly --platform=openshift --installer=operator

provisionOAuth

chectl auth:login -u admin -p admin
chectl workspace:create --start --devfile="https://raw.githubusercontent.com/eclipse-che/che-devfile-registry/master/devfiles/go/devfile.yaml"
waitWorkspaceStart
