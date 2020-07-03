
# Dockerfile to bootstrap build and test in openshift-ci

FROM registry.svc.ci.openshift.org/openshift/release:golang-1.12

RUN yum install --assumeyes -d1 python3-pip
RUN pip3 install --upgrade setuptools
RUN pip3 install yq
