##
# Copyright 2019 ETSI
#
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
##


FROM ubuntu:16.04

LABEL authors="Michael Marchetti"

RUN apt-get update && apt-get -y install curl software-properties-common

RUN apt-get update && apt-get -y install python \
    libcurl4-gnutls-dev libgnutls-dev iputils-ping python-pip \
    python-openstackclient wget

RUN pip install -U pip && python -m pip install python-magic pyangbind pytest==4.6.3

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} devops osmclient IM" && apt update

ARG OSMCLIENT_VERSION
ARG DEVOPS_VERSION
ARG IM_VERSION

RUN apt-get update && apt-get -y install osm-devops${DEVOPS_VERSION} python-osmclient${OSMCLIENT_VERSION} python-osm-im${IM_VERSION}

ENV OSM_SOL005=True
ENV OSM_HOSTNAME=nbi:9999
ENV OSM_RO_HOSTNAME=ro:9090
