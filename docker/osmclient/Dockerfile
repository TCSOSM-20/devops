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


FROM ubuntu:18.04

MAINTAINER Gerardo Garcia <gerardo.garciadeblas@telefonica.com>; Jayant Madavi <JM00553988@techmahindra.com>

RUN apt-get update && apt-get -y install curl software-properties-common

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install wget python3 python3-pip \
    libcurl4-gnutls-dev python3-openstackclient

RUN python3 -m pip install -U pip && python3 -m pip install pyyaml python-magic pyangbind pytest==4.6.3

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseSEVEN-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} devops osmclient IM" && apt-get update

ARG OSMCLIENT_VERSION
ARG DEVOPS_VERSION
ARG IM_VERSION

RUN apt-get update && apt-get -y install osm-devops${DEVOPS_VERSION} \
    python3-osm-im${IM_VERSION} python3-osmclient${OSMCLIENT_VERSION}
ENV OSM_SOL005=True
ENV OSM_HOSTNAME=nbi:9999

