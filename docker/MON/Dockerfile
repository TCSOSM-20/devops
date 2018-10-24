# Copyright 2018 Whitestack, LLC
# *************************************************************

# This file is part of OSM Monitoring module
# All Rights Reserved to Whitestack, LLC

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at

#         http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# For those usages not covered by the Apache License, Version 2.0 please
# contact: bdiaz@whitestack.com or glavado@whitestack.com
##

FROM ubuntu:16.04

LABEL authors="Guillermo Calvino"

RUN apt-get update && apt-get -y install curl software-properties-common

RUN apt-get --yes update \
 && apt-get --yes install git python python-pip python3 python3-pip libmysqlclient-dev libssl-dev libffi-dev \
 && pip3 install pip==9.0.3

ARG REPOSITORY_BASE=http://osm-download.etsi.org/repository/osm/debian
ARG RELEASE=ReleaseFOUR-daily
ARG REPOSITORY_KEY=OSM%20ETSI%20Release%20Key.gpg
ARG REPOSITORY=testing

RUN curl ${REPOSITORY_BASE}/${RELEASE}/${REPOSITORY_KEY} | apt-key add -
RUN add-apt-repository -y "deb ${REPOSITORY_BASE}/${RELEASE} ${REPOSITORY} MON common" && apt update

ARG MON_VERSION
ARG COMMON_VERSION

RUN apt-get --yes update  && apt-get -y install python3-osm-common${COMMON_VERSION} python3-osm-mon${MON_VERSION}

COPY scripts/ scripts/

ENV BROKER_URI kafka:9092
ENV MONGO_URI mongo:27017
ENV DATABASE sqlite:///mon_sqlite.db
ENV OS_NOTIFIER_URI localhost:8662
ENV OS_DEFAULT_GRANULARITY 300
ENV REQUEST_TIMEOUT 10

EXPOSE 8662

CMD /bin/bash scripts/runInstall.sh
