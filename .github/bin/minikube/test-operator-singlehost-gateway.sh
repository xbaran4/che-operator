#!/usr/bin/env bash
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

set -e
set -x
set -u

# Get absolute path for root repo directory from github actions context: https://docs.github.com/en/free-pro-team@latest/actions/reference/context-and-expression-syntax-for-github-actions
export OPERATOR_REPO="${GITHUB_WORKSPACE}"
source "${OPERATOR_REPO}"/.github/bin/common.sh
source "${OPERATOR_REPO}/olm/olm.sh"

# Stop execution on any error
trap "catchFinish" EXIT SIGINT

prepareTemplates() {
  disableUpdateAdminPassword ${TEMPLATES}
  setCustomOperatorImage ${TEMPLATES} ${OPERATOR_IMAGE}
  setServerExposureStrategy ${TEMPLATES} "single-host"
  enableDevWorkspace ${TEMPLATES} true
  setSingleHostExposureType ${TEMPLATES} "gateway"
  setIngressDomain ${TEMPLATES} "$(minikube ip).nip.io"
}

runTest() {
  deployEclipseChe "operator" "minikube" ${OPERATOR_IMAGE} ${TEMPLATES}
  startNewWorkspace
  waitWorkspaceStart
}

initDefaults
initLatestTemplates
prepareTemplates
buildCheOperatorImage
copyCheOperatorImageToMinikube
runTest
